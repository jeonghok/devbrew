#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_status.py — 로드맵과 git 을 읽어 에픽별 단계 · 경고 · 정보를 낸다.

명령줄:
  roadmap_status.py <로드맵 경로>           기본 브랜치(origin/HEAD)의 로드맵을 읽는다(레포 상대경로)
  roadmap_status.py --roadmap-file <파일>   작업 트리의 로드맵을 읽는다(아직 기본 브랜치에 없을 때)
  --json 이면 JSON 하나를 낸다.

종료 코드: 0 이상 없음 · 1 경고 있음 · 2 사용법 오류 · 3 검사 불가(로드맵 없음 · 형식 깨짐 ·
블록 하나라도 알 수 없음 · 번호 대조 검사 불가 · 미룸 표 깨짐 · 번호 전체 집합을 못 셈) ·
4 로드맵이 아직 기본 브랜치에 없음(머지 전 — `--roadmap-file` 로 계산한다). 3 > 4 > 1 > 0.
정보(경로 예약 겹침 · 다른 에픽이 예약한 파일의 편집)는 종료 코드를 바꾸지 않는다 — 충돌은 머지 때 푼다.

읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다. git 은 `GIT_ALLOWED` 의 하위 명령만
부르고 fetch 하지 않는다(지휘 절차가 계산 전에 fetch 한다). 단계는 git 으로 알 수 있는 것까지다 —
구현 중 · 구현 끝은 계획 파일과 설계문서의 구현 대조 절로 센다. PR 단계는 여기서 세지 않고
control_plane 이 기계 상태 또는 `gh` 로 덧씌운다.
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
    DEFAULT_REF, EXTRA_FIELDS, FormatError, NO_DEFAULT, approval_date, RECORD_HEADING, RULINGS_HEADING, brief_universe, collect_assigned, field_list, field_text,
    frontmatter, handoff_rows, id_sort_key, impl_done, parse_ids, parse_roadmap,
    section_body, section_lines, split_list, unquote)
from repo_defaults import SPECS_DIR, repo_settings  # noqa: E402

GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"})
NOTICE = ("머지됨 자동 판정은 merge commit 방식에서만 된다 — 브랜치가 지워졌으면 GitHub 의 머지 메시지 "
          "`Merge pull request #<n> from <owner>/<브랜치>` 로만 알아본다. squash · rebase 로 머지했거나 "
          "로컬에서 머지한 뒤 브랜치를 지웠으면 로드맵 결정 기록에 머지 줄을 적는다(여러 브랜치 블록이면 머지한 브랜치 이름만 적는다 — 줄은 쌓이고 머지한 브랜치마다 한 줄이면 된다). 경로 예약 겹침과 다른 에픽이 "
          "예약한 파일의 편집은 경고가 아니라 정보다 — 에픽은 병렬로 가고 충돌은 머지 때 푼다(나중 PR 이 기본 브랜치를 "
          "merge 하고 스위트를 다시 돌린다).")
# 경로 예약 겹침 · 위반에서 빼는 공유 파일 — 버전은 머지 직전에 정한다(N6).
SHARED_BASENAMES = ("plugin.json", "CHANGELOG.md", "README.md")
TASK_STATUS = {"대기": "pending", "준비": "pending", "설계 중": "in_progress", "계획": "in_progress",
               "구현 중": "in_progress", "구현 끝": "in_progress", "PR": "in_progress",
               "머지됨": "completed", "끝남": "completed"}


def task_status(stage):
    if stage and stage.startswith("일부 머지"):
        return "in_progress"
    return TASK_STATUS.get(stage)


DONE = ("머지됨", "끝남")
PAST_PLAN = ("계획", "구현 중", "구현 끝", "PR", "머지됨")

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

    def default_branch(self):
        """(커밋, 이름) — origin/HEAD 가 가리키는 기본 브랜치. 못 풀면 (None, None)."""
        sha = self.commit(DEFAULT_REF)
        if not sha:
            return None, None
        rc, out = self.run("rev-parse", "--symbolic-full-name", DEFAULT_REF)
        full = out.strip() if rc == 0 else ""
        return sha, (full[len("refs/remotes/"):] if full.startswith("refs/remotes/") else "origin/HEAD")

    def first_parent_merges(self, main):
        rc, out, err = self.run_err("log", "--first-parent", "--merges",
                                    "--format=%H%x09%P%x09%s", main)
        if rc != 0:
            self.fail("log", rc, err)
            return []
        merges = []
        for line in out.splitlines():
            parts = line.split("\t", 2)
            if len(parts) == 3:
                merges.append((parts[0], parts[1].split(), parts[2]))
        return merges

    def unmerged_tips(self, main: str):
        """기본 브랜치에 들어가지 않은 로컬 · origin 브랜치 끝(이름 붙은 커밋)들. 못 읽으면 []."""
        rc, out, err = self.run_err("log", "--simplify-by-decoration", "--format=%H", "--branches",
                                    "--remotes=origin", "--not", main)
        if rc != 0:
            self.fail("log", rc, err)
            return []
        return [l.strip() for l in out.splitlines() if l.strip()]

    def merge_base(self, a: str, b: str):
        rc, out = self.run("merge-base", a, b)
        return out.strip() if rc == 0 and out.strip() else None

    def changed(self, base: str, tip: str, pathspec=None):
        args = ["diff", "--name-only", "-z", "%s...%s" % (base, tip)]
        if pathspec:
            args += ["--", pathspec]
        rc, out, err = self.run_err(*args)
        if rc != 0:
            self.fail("diff", rc, err)
            return []
        return [p for p in out.split("\0") if p]

    def first_touch(self, base: str, tip: str, path: str):
        rc, out, err = self.run_err("log", "--format=%H", "--reverse", "%s..%s" % (base, tip), "--", path)
        if rc != 0:
            self.fail("log", rc, err)
            return None
        first = out.split("\n", 1)[0].strip()
        return first or None

    def trailer_after(self, commit: str, tip: str, base: str, lines: set) -> bool:
        """commit 뒤(commit 제외)에 이 브랜치가 더한 커밋 — base(기본 브랜치와 갈라진 곳)에서 닿는 것은 뺀다 —
        의 메시지에 lines 중 한 줄이 그대로 있는가."""
        rc, out, err = self.run_err("log", "--format=%x1e%B", tip, "^" + commit, "^" + base)
        if rc != 0:
            self.fail("log", rc, err)
            return False
        return any(line.strip() in lines for body in out.split("\x1e") for line in body.splitlines())

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
    """로드맵 · 묶음 · brief · audit 을 읽는 사본 — 기본 브랜치(rev) 또는 작업 트리(root)."""

    def __init__(self, git: Git, rev=None, root=None, label=None):
        self.git, self.rev, self.root = git, rev, root
        self.label = label or ("기본 브랜치" if rev else "작업 트리")

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


def spec_line_path(line: str):
    """`**Spec:**` 줄의 경로 — 바로 뒤가 백틱이면 그 안, 아니면 줄에서 처음 나오는 백틱 토큰, 그것도 없으면
    첫 일반 토큰(뒤의 `,.;:)` 와 짝 없는 백틱, 앞의 `(` 를 뗀다)."""
    rest = line.lstrip()[len("**Spec:**"):].strip()
    if rest.startswith("`"):
        m = BACKTICK_RE.match(rest)
        return m.group(1) if m else None
    m = BACKTICK_RE.search(rest)
    if m:
        return m.group(1)
    tok = rest.split()[0].strip("`").rstrip(",.;:)").lstrip("(").strip("`") if rest.split() else ""
    return tok or None


def plan_specs(text: str) -> set:
    return {p for p in (spec_line_path(l) for l in text.splitlines() if l.lstrip().startswith("**Spec:**")) if p}


def find_specs(git: Git, tree: str, block: dict, bundle_path, specs_dir: str):
    if "산출물" in block["fields"]:
        return [p for p in field_list(block["fields"]["산출물"]) if git.exists(tree, p)]
    if block["kind"] == "branch":
        spec = field_text(block["fields"]["spec"]).strip().strip("`")
        return [spec] if git.exists(tree, spec) else []
    if block["kind"] != "bundle" or bundle_path is None:
        return []
    found = []
    for path in git.grep_files(tree, bundle_path, specs_dir):
        text = git.blob(tree, path)
        if text and unquote(frontmatter(text).get("source_interview", "")) == bundle_path:
            found.append(path)
    return sorted(found)


def branch_plans(git: Git, base: str, tip: str, specs: list, plans_dir: str) -> list:
    """이 브랜치가 기본 브랜치에서 갈라진 뒤 바꾼 계획 가운데 그 설계문서를 가리키는 것 — (경로, 처음 더한 커밋)."""
    out = []
    for path in git.changed(base, tip, plans_dir):
        text = git.blob(tip, path)
        if text is None or not (plan_specs(text) & set(specs)):
            continue
        out.append((path, git.first_touch(base, tip, path)))
    return sorted(out)


def approval_of(git: Git, tip: str, specs: list):
    """(가장 늦은 spec 승인 날짜 | None, 읽기 불가 사유 | None) — 그 브랜치 설계문서들의 `## 지휘 기록`."""
    dates = []
    for s in specs:
        try:
            d = approval_date(git.blob(tip, s) or "")
        except FormatError as exc:
            return None, "지휘 기록 읽기 불가 — %s(%s)" % (exc, s)
        if d:
            dates.append(d)
    return (max(dates) if dates else None), None


def progress(git: Git, main: str, tip: str, block: dict, bundle_path, settings: dict):
    """(단계, 근거, 설계문서들, 계획들) — 브랜치 하나의 진행. 앞 계획의 구현 대조 절은 뒤 계획을 끝내지 않는다."""
    specs = find_specs(git, tip, block, bundle_path, settings["specs_dir"])
    block.setdefault("approved", None)
    if not specs:
        return "설계 중", "브랜치 있음 · spec 없음", [], []
    base = git.merge_base(main, tip)
    if base is None:
        return "설계 중", "spec 있음 · 기본 브랜치와 갈라진 곳을 못 찾았다", specs, []
    plans = branch_plans(git, base, tip, specs, settings["plans_dir"])
    if not plans:
        when, why = approval_of(git, tip, specs)
        block["approved"] = when
        if why:
            return "설계 중", "spec 있음 · " + why, specs, []
        if when:
            return "설계 중", "spec 승인됨(%s) · 계획 없음" % when, specs, []
        return "설계 중", "spec 있음", specs, []
    texts = [git.blob(tip, s) or "" for s in specs]
    done = [p for p, _c in plans if any(impl_done(t, p) for t in texts)]
    paths = [p for p, _c in plans]
    if len(done) == len(plans):
        return "구현 끝", "구현 대조 절 있음: %s" % " · ".join(done), specs, paths
    trailers = {"Spec: " + s for s in specs}
    started = [p for p, c in plans if p not in done and c and git.trailer_after(c, tip, base, trailers)]
    if started or done:
        why = (["구현 대조 절 있음: %s" % " · ".join(done)] if done else []) + (
            ["Spec: 트레일러 커밋 있음: %s" % " · ".join(started)] if started else [])
        return "구현 중", " · ".join(why), specs, paths
    return "계획", "계획 있음", specs, paths


def names_branch(text: str, branch: str) -> bool:
    """text 에 브랜치 이름이 통째로 적혀 있는가 — 이름 글자는 ASCII 영숫자와 `/._-` 뿐이라 한글 조사는 경계다.
    이름 뒤의 `.` 이 공백이나 글의 끝 앞이면 문장 부호로 본다."""
    def name_char(ch: str) -> bool:
        return ch != "" and ch.isascii() and (ch.isalnum() or ch in "/._-")

    at = text.find(branch)
    while at != -1:
        end = at + len(branch)
        before, after = text[at - 1:at] if at else "", text[end:end + 1]
        if after == "." and not text[end + 1:end + 2].strip():
            after = ""
        if not name_char(before) and not name_char(after):
            return True
        at = text.find(branch, at + 1)
    return False


def merged_by(git: Git, merges: list, main: str, branch: str, tip):
    """머지됨 근거 한 줄, 아니면 None. 조상 관계만으로는 머지됨이 아니다(D1.1)."""
    if tip:
        for sha, parents, _subj in merges:
            if len(parents) >= 2 and parents[1] == tip and not git.is_ancestor(tip, parents[0]):
                return "기본 브랜치의 머지 커밋 %s" % sha[:8]
    # 머지 메시지가 이 브랜치를 정확히 부른다 — 브랜치가 지워졌거나, 남은 브랜치 끝이 기본 브랜치에 다 들어가
    # 있을 때만(머지 뒤 로컬 브랜치를 기본 브랜치로 앞당긴 경우). 머지 뒤 커밋이 더 붙었으면 머지됨이 아니다.
    if tip and not git.is_ancestor(tip, main):
        return None
    for sha, _parents, subj in merges:
        m = MERGE_MSG_RE.fullmatch(subj.strip())
        if m and m.group(1) == branch:
            return "머지 메시지 %s (%s)" % (sha[:8], "브랜치 끝이 기본 브랜치에 들어 있음" if tip
                                          else "브랜치는 지워짐")
    return None


def extra_branches(git: Git, main: str, rel: str, blocks: list):
    """({에픽 번호: [브랜치 …]}, 형식이 깨진 사본 수) — 기본 브랜치의 블록 `브랜치:` 에 없는데, 기본 브랜치에 아직
    들어가지 않은 브랜치의 로드맵 사본이 그 블록에 더한 이름(처음 본 차례). 계획 2 의 브랜치는 자기 브랜치의 사본에서만
    블록에 자신을 더하므로 기본 브랜치 사본만 읽으면 계획 1 머지 뒤 에픽이 「머지됨」으로 보인다. 사본의 블록이 기본 브랜치
    블록의 브랜치를 모두 품을 때만 그 블록을 잇는 사본으로 본다 — 재분해 전 · 같은 경로를 다시 쓴 낡은 사본은 세지 않는다.
    로드맵 파일이 없는 사본은 건너뛰고, 형식이 깨진 사본은 읽을 수 있는 블록만 쓰되 그 수를 낸다.
    한계: 사본을 만든 뒤 기본 브랜치 블록의 `브랜치:` 가 바뀌면(재분해) 그 사본은 블록을 품지 못해 세지 않는다 —
    열린 브랜치에 기본 브랜치를 merge 하면(지휘 순환 걸음 6) 풀린다."""
    listed = {b["id"]: list(b["branches"]) for b in blocks if b["kind"] != "decision"}
    out, broken = {}, 0
    for tip in git.unmerged_tips(main):
        text = git.blob(tip, rel)
        if not text:
            continue
        try:
            _meta, other, _rec, _risk, errs = parse_roadmap(text)
        except FormatError:
            other, errs = [], ["형식 깨짐"]
        if errs:
            broken += 1
        for ob in other:
            mine = listed.get(ob["id"])
            theirs = ob.get("branches") or []
            if not mine or not set(mine) <= set(theirs):
                continue
            for br in theirs:
                if br not in mine and br not in out.setdefault(ob["id"], []):
                    out[ob["id"]].append(br)
    return out, broken


class _GitTreeRepo:
    """check() 가 로드맵 · 다른 묶음의 설계문서를 읽는 자리 — 작업 트리가 아니라 한 커밋(기본 브랜치)의 트리에서."""

    def __init__(self, git: Git, tree: str, specs_dir=None):
        self.git, self.tree, self.specs_dir = git, tree, specs_dir
        self._memo = {}

    def read(self, rel: str):
        return self.git.blob(self.tree, rel)

    def exists(self, rel: str) -> bool:
        return self.git.exists(self.tree, rel)

    def specs_for(self, source: str, specs_dir=None) -> list:
        folder = specs_dir or self.specs_dir or SPECS_DIR
        key = (source, folder)
        if key in self._memo:
            return self._memo[key]
        out = []
        for path in self.git.grep_files(self.tree, source, folder):
            text = self.git.blob(self.tree, path)
            if text and unquote(frontmatter(text).get("source_interview", "")) == source:
                out.append((path, text))
        self._memo[key] = sorted(out)
        return self._memo[key]


def compute(git: Git, main, blocks: list, records: list, bundles: dict, roadmap_dir: str, settings: dict,
            roadmap_rel=None):
    """블록마다 stage · reason · warnings · notes · specs 를 채운다. 반환: 번호 대조 검사 불가 사유 목록.
    roadmap_rel 을 주면 블록에 적힌 브랜치가 모두 머지된 에픽에서 다른 브랜치의 로드맵 사본이 더한 브랜치도 센다."""
    merges = git.first_parent_merges(main) if main else []
    extra_cache = []

    def extras_for(bid):
        """(더한 브랜치 이름들, 형식이 깨진 사본 수)."""
        if roadmap_rel is None or main is None:
            return [], 0
        if not extra_cache:
            extra_cache.append(extra_branches(git, main, roadmap_rel, blocks))
        found, broken = extra_cache[0]
        return found.get(bid, []), broken
    by_id = {b["id"]: b for b in blocks}
    rec = {(r["block"], r["kind"]): r for r in records}
    merge_lines = {}
    for r in records:
        if r["kind"] == "머지":
            merge_lines.setdefault(r["block"], []).append(r)
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
        b.update(stage=None, approved=None, reason="", warnings=[], notes=[], specs=[], tip=None, branch_states=[], plans=[], docs=[], deferred=[],
                 bundle=(roadmap_dir + "/" + b["fields"]["묶음"]) if b["kind"] == "bundle" else None)
        undone = [d for d in b["deps"] if by_id[d]["stage"] not in DONE]
        if main is None:
            b["stage"], b["reason"] = "알 수 없음", "기본 브랜치를 못 읽었다"
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
        bundle_path = b["bundle"]
        states = []
        for br in b["branches"]:
            tip = git.commit("refs/heads/" + br) or git.commit("refs/remotes/origin/" + br)
            states.append({"branch": br, "tip": tip, "merged": merged_by(git, merges, main, br, tip)})
        b["branch_states"] = states
        rec_merge = rec.get((bid, "머지"))
        if rec_merge and len(states) > 1 and not all(s["merged"] for s in states):
            # 브랜치가 여럿이면 머지 줄은 쌓인다 — 글에 이름이 적힌 브랜치에만 닿고, 그 ref 가 사라졌을 때만 머지로 센다.
            for s in states:
                if s["merged"]:
                    continue
                line = next((r for r in merge_lines[bid] if names_branch(r["quote"], s["branch"])), None)
                if line is None:
                    b["warnings"].append("결정 기록의 머지 줄이 %s 를 가리키지 않아 적용하지 않았다" % s["branch"])
                elif s["tip"] is None:
                    s["merged"] = "결정 기록의 머지 기록 %s %s" % (line["date"], line["quote"])
                else:
                    b["warnings"].append("결정 기록의 머지 줄을 %s 에 적용하지 않았다 — 브랜치가 남아 있다"
                                         % s["branch"])
            rec_merge = None
        n_merged = sum(1 for s in states if s["merged"])
        if states and (n_merged == len(states) or rec_merge):
            more = []
            names, broken = extras_for(bid)
            if broken:
                b["notes"].append("기본 브랜치에 아직 들어가지 않은 브랜치의 로드맵 사본 %d개는 형식이 깨져 읽은 블록만 셌다 — "
                                  "그 사본이 이 블록에 더한 브랜치는 세지 못했을 수 있다" % broken)
            for br in names:
                tip = git.commit("refs/heads/" + br) or git.commit("refs/remotes/origin/" + br)
                if tip and not merged_by(git, merges, main, br, tip):
                    more.append({"branch": br, "tip": tip, "merged": None})
            if more:
                if rec_merge:
                    for s in states:
                        s["merged"] = s["merged"] or "결정 기록의 머지 기록 %s %s" % (rec_merge["date"], rec_merge["quote"])
                    rec_merge = None
                states.extend(more)
                b["branches"] = b["branches"] + [s["branch"] for s in more]
                b["notes"].append("블록 `브랜치:` 에 없는 %s 도 셌다 — 기본 브랜치에 아직 들어가지 않은 브랜치의 로드맵 "
                                  "사본이 이 블록에 더했다" % " · ".join(s["branch"] for s in more))
                n_merged = sum(1 for s in states if s["merged"])
        active = next((s for s in states if not s["merged"] and s["tip"]), None)
        b["tip"] = active["tip"] if active else None
        if n_merged == len(states) or rec_merge:
            why = (" · ".join(s["merged"] for s in states) if n_merged == len(states)
                   else "결정 기록의 머지 기록 %s %s" % (rec_merge["date"], rec_merge["quote"]))
            b["stage"], b["reason"], b["tip"] = "머지됨", why, None
            b["specs"] = find_specs(git, main, b, bundle_path, settings["specs_dir"])
        elif active is None:
            if n_merged:
                nxt = next(s["branch"] for s in states if not s["merged"])
                b["stage"], b["reason"] = "일부 머지 %d/%d" % (n_merged, len(states)), "다음 브랜치 없음: %s" % nxt
                b["specs"] = find_specs(git, main, b, bundle_path, settings["specs_dir"])
            elif undone:
                b["stage"], b["reason"] = "대기", "의존 미완료: %s" % " · ".join(undone)
            else:
                b["stage"], b["reason"] = "준비", "의존 완료 · 브랜치 없음"
        else:
            stage, reason, b["specs"], b["plans"] = progress(git, main, active["tip"], b, bundle_path, settings)
            if n_merged:
                b["stage"] = "일부 머지 %d/%d" % (n_merged, len(states))
                b["reason"] = "%s — %s · %s" % (active["branch"], stage, reason)
            else:
                b["stage"], b["reason"] = stage, reason
            if undone:
                b["warnings"].append("의존 미머지 상태에서 진행 중: %s" % " · ".join(undone))
        if b["kind"] == "bundle" and bundles.get(bid) is None:
            b["warnings"].append("묶음 없음: %s" % bundle_path)
        if len(b["specs"]) > 1:
            b["warnings"].append("spec 여럿: %s" % " · ".join(b["specs"]))
        if b["stage"] in PAST_PLAN or b["stage"].startswith("일부 머지"):
            if b["kind"] == "bundle" and not b["specs"]:
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음이라 배정 번호 %d개를 "
                                     "대조하지 않았다" % len(b["assigned"]))
            elif b["kind"] == "branch":
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 묶음이 아닌 블록이라 배정 번호 %s 를 대조하지 "
                                     "않았다" % " · ".join(sorted(b["assigned"], key=id_sort_key)))
        tree = b["tip"] or main
        known_ids = set(by_id)
        for spec in b["specs"]:
            spec_text = git.blob(tree, spec)
            if spec_text is None:
                b["warnings"].append("번호 대조 검사 불가(spec 을 읽지 못했다): %s" % spec)
                cov_unknown.append("%s spec 을 읽지 못했다" % bid)
                continue
            b["docs"].append((spec, spec_text))
            no_cov_section = cov_broken = False
            try:
                no_cov_section = "산출물" in b["fields"] and section_body(spec_text, "## 번호 대조") is None
            except FormatError as exc:
                cov_broken = True
                b["warnings"].append("번호 대조 검사 불가(%s): %s" % (exc, spec))
                cov_unknown.append("%s 산출물 번호 대조 절 — %s" % (bid, exc))
            if cov_broken:
                pass  # 미룸 표는 이 절과 상관없이 아래에서 읽는다
            elif no_cov_section:
                b["warnings"].append("번호 대조 건너뜀(셀 수 없음) — 산출물에 `## 번호 대조` 절이 없다: %s" % spec)
            elif b["kind"] == "bundle" and bundles.get(bid) is not None:
                result = check(bundles[bid], spec_text, repo=_GitTreeRepo(git, main, settings["specs_dir"]) if main else None)
                for w in coverage_warnings(result, spec):  # 경고 줄이라 종료 코드가 1 이 될 수 있다(막는 소비자 없음)
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
            b["deferred"].append((spec, rows))
            bad = [item for item, _why, recv in rows if not receiver_ok(recv, known_ids)]
            if bad:
                b["warnings"].append("받는 곳 없는 미룸 %d개: %s — %s" % (len(bad), spec, " · ".join(bad)))

    for b in blocks:
        if b["tip"]:
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
    unknown = result.get("unknown") or []
    if unknown:
        out.append("번호 대조 셀 수 없음 %d개: %s — %s" % (len(unknown), spec, " · ".join(unknown)))
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


def parallel_with(blocks: list, overlap_list: list) -> dict:
    """블록마다 함께 갈 수 있는 끝나지 않은 블록 — 의존 관계가 어느 쪽으로도 없는 것. 경로 예약 겹침은 정보로 함께."""
    reach = _reachable(blocks)
    over = {}
    for o in overlap_list:
        a, b = o["blocks"]
        over[(a, b)] = over[(b, a)] = o["paths"]
    out = {}
    for a in blocks:
        if a["stage"] in DONE:
            out[a["id"]] = []
            continue
        out[a["id"]] = [{"id": b["id"], "overlap": over.get((a["id"], b["id"]), [])} for b in blocks
                        if b["id"] != a["id"] and b["stage"] not in DONE
                        and b["id"] not in reach[a["id"]] and a["id"] not in reach[b["id"]]]
    return out


def _read_sections(block: dict, heading: str, label: str):
    """블록의 설계문서마다 `heading` 절을 읽는다. 반환: ([(spec, 줄들 | None)], [읽기 불가 사유]). 머리가 둘인
    문서는 그 블록 경고로 올리고 사유를 돌려준다 — 다른 문서 · 블록은 그대로 읽는다."""
    got, errs = [], []
    for spec, text in block.get("docs", []):
        try:
            got.append((spec, section_lines(text, heading)))
        except FormatError as exc:
            errs.append(str(exc))
            block["warnings"].append("%s 읽기 불가(%s): %s" % (label, exc, spec))
    return got, errs


# ── 출력 ─────────────────────────────────────────────────────────────────────

def build(git: Git, args) -> dict:
    report = {"roadmap": None, "source": None, "default_branch": None, "not_on_default": False,
              "fetched_at": git.fetched_at(), "notice": NOTICE, "blocks": [], "unassigned": None,
              "orphans": None, "unknown_ids": [], "overlaps": [], "format_errors": [], "unknown_reasons": [],
              "settings": None, "handoffs": None, "exit": 3}
    main, main_name = git.default_branch()
    report["default_branch"] = main_name
    if args.roadmap_file:
        top = git.toplevel()
        if top is None:
            report["unknown_reasons"].append("git 레포 안이 아니다")
            return report
        rel = os.path.relpath(os.path.realpath(args.roadmap_file), os.path.realpath(top))
        src = Source(git, root=top)
        if main is None:
            report["unknown_reasons"].append(NO_DEFAULT)
    else:
        rel = args.roadmap.strip("/")
        report["roadmap"] = rel
        if main is None:
            report["unknown_reasons"].append(NO_DEFAULT)
            report["source"] = "기본 브랜치"
            return report
        src = Source(git, rev=main, label=main_name)
        if not src.exists(rel):
            report["source"], report["not_on_default"] = main_name, True
            return report
    report["roadmap"], report["source"] = rel, src.label
    text = src.read(rel)
    if text is None:
        report["unknown_reasons"].append("로드맵을 못 읽었다: %s (%s)" % (rel, src.label))
        return report
    meta, blocks, records, risk_rows, errors = parse_roadmap(text)
    settings = repo_settings(meta)
    report["settings"] = dict((k, settings[k]) for k in ("specs_dir", "plans_dir", "test_command",
                                                            "review_model", "parallel_default", "sources"))
    errors = errors + settings["errors"]
    report["format_errors"] = errors
    if errors:
        report["blocks"] = [{"id": b["id"], "title": b["title"], "kind": b.get("kind"),
                             "stage": "알 수 없음", "reason": "로드맵 형식 깨짐",
                             "task_status": None, "branch": field_text(b["fields"].get("브랜치", "")),
                             "branches": [], "branch_states": [], "tip": None, "plans": [],
                             "deps": [], "specs": [], "ids": [], "warnings": [], "notes": [],
                             "bundle": None, "extras": {}, "parallel": None, "rulings_archived": None}
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

    cov_unknown = compute(git, main, blocks, records, bundles, roadmap_dir, settings, roadmap_rel=rel)
    report["unknown_reasons"] += ["번호 대조 검사 불가 — %s" % c for c in cov_unknown]
    report["unknown_reasons"] += ["git 읽기 실패 — %s" % f for f in git.failures]
    report["overlaps"] = overlaps(blocks)
    stages = dict((b["id"], b["stage"]) for b in blocks)
    records, bad_records, rulings = {}, {}, {}
    for b in blocks:
        got, errs = _read_sections(b, RECORD_HEADING, "지휘 기록")
        records[b["id"]] = "\n".join("\n".join(lines or []) for _spec, lines in got)
        if errs:
            bad_records[b["id"]] = errs[0]
            report["unknown_reasons"].append("%s 지휘 기록 읽기 불가 — %s" % (b["id"], errs[0]))
        got, errs = _read_sections(b, RULINGS_HEADING, "판정")
        if errs:
            report["unknown_reasons"].append("%s 판정 읽기 불가 — %s" % (b["id"], errs[0]))
        elif any(lines is not None for _spec, lines in got):
            rulings[b["id"]] = [l for _spec, lines in got for l in (lines or []) if l.startswith("- ")]
    givers = [(b["id"], spec, rows) for b in blocks for spec, rows in b.get("deferred", [])]
    report["handoffs"] = handoff_rows(givers, stages, records)
    for h in report["handoffs"]:
        if h["receiver"] in bad_records and h["state"] in ("열림", "처리됨", "확인됨"):
            h.update(state="셀 수 없음", basis="%s 지휘 기록 읽기 불가" % h["receiver"])
    parallel = parallel_with(blocks, report["overlaps"])
    for b in blocks:
        ids = b["assigned"]
        report["blocks"].append({
            "id": b["id"], "title": b["title"], "kind": b["kind"], "stage": b["stage"],
            "reason": b["reason"], "task_status": task_status(b["stage"]),
            "branch": field_text(b["fields"].get("브랜치", "")), "branches": b["branches"],
            "branch_states": b.get("branch_states", []), "tip": b.get("tip"), "plans": b.get("plans", []),
            "deps": b["deps"], "specs": b["specs"],
            "bundle": b["bundle"],
            "extras": dict((k, v) for k in EXTRA_FIELDS if k in b["fields"]
                           for v in [field_text(b["fields"][k])] if v != "없음"),
            "parallel": parallel.get(b["id"], []), "rulings_archived": rulings.get(b["id"]),
            "ids": sorted(ids, key=id_sort_key), "warnings": b["warnings"], "notes": b["notes"]})
    return report


def exit_code(report: dict) -> int:
    """notes · overlaps 는 정보라 세지 않는다."""
    if report.get("not_on_default") and not report["format_errors"] and not report["unknown_reasons"]:
        return 4
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
    lines = ["로드맵 상태 — 블록 %d개 · 경고 %d개 · 정보 %d개 · 검사 불가 %d개 (사본: %s · 받은 시각: %s)"
             % (len(report["blocks"]), nwarn, ninfo,
                len(report["format_errors"]) + len(report["unknown_reasons"]),
                report["source"] or "알 수 없음", report["fetched_at"] or "알 수 없음"),
             report["notice"], ""]
    if report.get("not_on_default"):
        lines.append("로드맵이 아직 기본 브랜치(%s)에 없다 — 머지 전이면 `--roadmap-file` 로 계산한다: %s"
                     % (report.get("default_branch") or "알 수 없음", report.get("roadmap")))
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
    where.add_argument("roadmap", nargs="?", help="기본 브랜치 기준 로드맵 레포 상대경로")
    where.add_argument("--roadmap-file", help="작업 트리의 로드맵 파일")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    try:
        report = build(Git(os.getcwd()), args)
        report["exit"] = exit_code(report)
    except Exception as exc:  # 계산이 죽어도 이상 없음(0)·경고(1)로 내지 않는다
        report = {"roadmap": None, "source": None, "default_branch": None, "not_on_default": False,
                  "fetched_at": None, "notice": NOTICE,
                  "blocks": [], "unassigned": None, "orphans": None, "unknown_ids": [],
                  "overlaps": [], "format_errors": [],
                  "unknown_reasons": ["내부 오류 — %s: %s" % (type(exc).__name__, exc)],
                  "settings": None, "handoffs": None, "exit": 3}
    print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else render(report))
    return report["exit"]


if __name__ == "__main__":
    sys.exit(main())
