#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_status.py — 로드맵과 git 을 읽어 에픽별 단계 · 경고 · 정보를 낸다.

명령줄:
  roadmap_status.py <로드맵 경로>           기본 브랜치(origin/HEAD)의 로드맵을 읽는다(레포 상대경로)
  roadmap_status.py --roadmap-file <파일>   작업 트리의 로드맵을 읽는다(아직 기본 브랜치에 없을 때)
  --json 이면 JSON 하나를 낸다. 보고의 `read_tree` 는 로드맵을 읽은 트리, 블록의 `read_tree` 는 그 에픽의 단계 · spec 을
  읽은 트리다(기본 브랜치 · 에픽 끝 · 이 작업공간).

종료 코드: 0 이상 없음 · 1 경고 있음 · 2 사용법 오류 · 3 검사 불가(로드맵 없음 · 형식 깨짐 ·
블록 하나라도 알 수 없음 · 번호 대조 검사 불가 · 미룸 표 깨짐 · 번호 전체 집합을 못 셈) ·
4 로드맵이 아직 기본 브랜치에 없음(머지 전 — `--roadmap-file` 로 계산한다). 3 > 4 > 1 > 0.
정보(경로 예약 겹침 · 다른 에픽이 예약한 파일의 편집)는 종료 코드를 바꾸지 않는다 — 충돌은 머지 때 푼다.

읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다. git 은 `GIT_ALLOWED` 의 하위 명령만
부르고 fetch 하지 않는다(지휘 절차가 계산 전에 fetch 한다) — 밖의 git 은 origin 소유자를 읽는
`gh_repo.origin_slug` 의 `git remote get-url` 하나다. 머지됨은 기계 상태의 PR 캐시(지휘자가 채운다)로
판정하되 브랜치 끝이 기본 브랜치 머지 커밋의 둘째 부모면 캐시보다 먼저 머지됨이다(로컬 끝, 로컬이 원격의 조상이면
원격 끝 — 로컬이 없거나 기본 브랜치 안에서 원격보다 앞이면 그 머지가 이 에픽의 문서를 처음 더한 커밋보다 먼저가
아닐 때만 원격 끝. 로컬이 없을 때의 PR 판정도 같다). 그 브랜치의 줄이 캐시에 없으면 머지 커밋 · 이 레포 소유자의 머지 메시지 · 결정 기록의
머지 줄로 판정한다. 단계는 git 으로 알 수 있는 것까지다 —
구현 중 · 구현 끝은 계획 파일과 설계문서의 구현 대조 절로 센다. PR 단계는 여기서 세지 않고
control_plane 이 기계 상태의 PR 캐시로 덧씌운다.
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
from repo_defaults import SHARED_FILES, SettingsError, resolve  # noqa: E402
from repo_defaults import default_branch as _default_branch  # noqa: E402
from conductor_state import MachineError, machine_path, parse_machine  # noqa: E402 — PR 캐시 읽기만
from conductor_state import EPIC_PR, RECORDED_MISSING, recorded_cache_row, recorded_number  # noqa: E402 — 적은 번호 읽기만
from gh_repo import GhStop, origin_slug  # noqa: E402 — origin 소유자 읽기만
from state_path import state_root_for_common  # noqa: E402

GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"})
NOTICE = ("머지됨은 PR 상태로 판정한다(지휘자가 채운 PR 캐시) — 캐시가 없으면 머지 커밋과 이 레포 소유자의 머지 "
          "메시지로 알아보고 「PR 상태 미확인」을 보인다. "
          "지휘자가 PR 을 열 때 번호를 적은 에픽은 그 PR 로만 머지를 판정한다. 번호가 없는 에픽(이 판 전에 연 PR · 지휘자 밖에서 연 PR · "
          "번호 기록이 없는 다른 기계)은 브랜치 이름과 이력으로 알아보며, 같은 이름의 옛 브랜치가 머지됨으로 보이거나 머지된 에픽이 "
          "빠지는 틈이 남는다. 번호 기록은 기계 상태라 이 기계에만 있다. 결정 기록의 머지 줄은 PR 없이 로컬에서 머지한 경우에만 쓴다"
          "(여러 브랜치 블록이면 머지한 브랜치 이름만 적는다 — 줄은 쌓이고 머지한 브랜치마다 한 줄이면 된다). 경로 예약 겹침과 다른 에픽이 "
          "예약한 파일의 편집은 경고가 아니라 정보다 — 에픽은 병렬로 가고 충돌은 머지 때 푼다(나중 PR 이 기본 브랜치를 "
          "merge 하고 스위트를 다시 돌린다).")
# 경로 예약 겹침 · 위반에서 빼는 공유 파일 — 버전은 머지 직전에 정한다(N6).
SHARED_BASENAMES = SHARED_FILES
TASK_STATUS = {"대기": "pending", "준비": "pending", "설계 중": "in_progress", "계획": "in_progress",
               "구현 중": "in_progress", "구현 끝": "in_progress", "PR": "in_progress",
               "머지됨": "completed", "끝남": "completed"}


def task_status(stage):
    if stage and stage.startswith("일부 머지"):
        return "in_progress"
    return TASK_STATUS.get(stage)


DONE = ("머지됨", "끝남")
READ_DEFAULT, READ_TIP, READ_WORKSPACE = "기본 브랜치", "에픽 끝", "이 작업공간"   # 읽은 트리(read_tree)
PAST_PLAN = ("계획", "구현 중", "구현 끝", "PR", "머지됨")

MERGE_MSG_RE = re.compile(r"Merge pull request #\d+ from ([^/\s]+)/(\S+)")
PR_MERGED, PR_NOT_FETCHED, PR_UNCOUNTABLE = "머지됨", "머지됨(받기 전)", "셀 수 없음"
FETCH_HINT = "git fetch 뒤 다시 계산한다"
PR_UNCHECKED = "PR 상태 미확인 — 지휘자를 돌려라"
HOLD = "머지 판정 보류 — 기계 상태를 읽지 못해 PR 번호 기록이 있는지 모른다"
BACKTICK_RE = re.compile(r"`([^`]+)`")


# ── git (읽기 전용) ──────────────────────────────────────────────────────────

class Git:
    def __init__(self, cwd: str):
        self.cwd = cwd
        self.env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_OPTIONAL_LOCKS="0",
                        GIT_TERMINAL_PROMPT="0", LC_ALL="C")
        self.failures = []
        self.default_reason = None

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
        return re.sub(r"\r\n?", "\n", out) if rc == 0 else None   # 게이트(작업 트리 읽기)와 같은 줄을 본다

    def exists(self, rev: str, path: str) -> bool:
        return self.run("cat-file", "-e", "%s:%s" % (rev, path))[0] == 0

    def is_ancestor(self, a: str, b: str) -> bool:
        return self.run("merge-base", "--is-ancestor", a, b)[0] == 0

    def common_dir(self):
        rc, out = self.run("rev-parse", "--git-common-dir")
        return out.strip() if rc == 0 and out.strip() else None

    def reverts_of(self, commit: str, main: str) -> list:
        """commit 뒤 기본 ref 의 커밋 가운데 메시지에 `This reverts commit <commit>` 이 든 것."""
        rc, out, err = self.run_err("log", "--format=%H", "--fixed-strings",
                                    "--grep=This reverts commit " + commit, "%s..%s" % (commit, main))
        if rc != 0:
            self.fail("log", rc, err)
            return []
        return [l.strip() for l in out.splitlines() if l.strip()]

    def default_branch(self):
        """(커밋, `origin/<짧은 이름>`) — origin/HEAD 가 가리키는 기본 브랜치. 못 풀면 (None, None) 이고 고치는 법은
        default_reason 에 남는다. 레포 밖이면 (None, None) — 레포 밖 사유는 부르는 쪽이 낸다."""
        if self.toplevel() is None:
            return None, None
        try:
            sha, short, self.default_reason = _default_branch(self.cwd)
        except SettingsError as exc:
            raise RuntimeError(str(exc))
        return (sha, "origin/" + short) if sha else (None, None)

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


def _shared(path: str, names=SHARED_BASENAMES) -> bool:
    return path.rsplit("/", 1)[-1] in names


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


def _merge_commit_of(git: Git, merges: list, tip):
    """기본 브랜치의 머지 커밋 가운데 둘째 부모가 tip 이고 tip 이 첫째 부모에 아직 없던 것, 아니면 None."""
    if tip:
        for sha, parents, _subj in merges:
            if len(parents) >= 2 and parents[1] == tip and not git.is_ancestor(tip, parents[0]):
                return sha
    return None


def merged_by_tips(git: Git, merges: list, main: str, tip_local, tip_remote, age_ok=None):
    """PR 캐시에 줄이 있어도 먼저 보는 머지 커밋 근거 한 줄, 아니면 None. 로컬 끝이 원격 끝의 조상(받기만 한 로컬)이면
    원격 끝만, 아니면 로컬 끝을 본다 — 그 끝이 기본 브랜치 머지 커밋의 둘째 부모면 머지됨. 원격 끝의 머지 커밋은 로컬 끝이
    없거나, 로컬 끝이 원격 끝보다 앞이고 기본 브랜치에 다 들어 있을 때도 세되 age_ok(머지 커밋)가 거짓이면 세지 않는다
    (그 머지가 이 에픽의 설계문서 · 산출물이 기본 브랜치에 처음 들어온 커밋보다 먼저다 — 같은 이름을 다시 쓴 옛 브랜치).
    age_ok 가 None 을 내면(견줄 문서가 없다) 센다. 로컬에 기본 브랜치 밖 커밋이 있으면 원격 끝은 세지 않는다."""
    stale = bool(tip_local and tip_remote and tip_local != tip_remote and git.is_ancestor(tip_local, tip_remote))
    if tip_local and not stale:
        sha = _merge_commit_of(git, merges, tip_local)
        if sha:
            return "기본 브랜치의 머지 커밋 %s" % sha[:8]
        if not (tip_remote and tip_remote != tip_local and git.is_ancestor(tip_remote, tip_local)
                and git.is_ancestor(tip_local, main)):
            return None
    sha = _merge_commit_of(git, merges, tip_remote)
    if not sha or (not stale and age_ok is not None and age_ok(sha) is False):
        return None
    return "기본 브랜치의 머지 커밋 %s(원격 끝)" % sha[:8]


def parse_fp_events(text: str) -> list:
    """`git log --first-parent -M --diff-filter=AR --name-status --format=%x00%H` 출력 → [(커밋, [(상태, [경로 …]) …]) …]
    (새 커밋부터)."""
    out = []
    for chunk in text.split("\x00")[1:]:
        lines = chunk.split("\n")
        changes = [(parts[0], parts[1:]) for parts in (l.split("\t") for l in lines[1:] if l.strip()) if len(parts) >= 2]
        out.append((lines[0].strip(), changes))
    return out


def first_added(events: list, path: str):
    """path 를 기본 브랜치 첫째 부모 줄에 처음 더한 커밋, 없으면 None. 이름 바꿈(R)은 옛 이름으로 따라가 그 이름의 추가를
    찾는다 — 복사(C)는 따라가지 않는다(틀이 같은 문서끼리 서로의 복사로 잡히지 않게)."""
    found = None
    for sha, changes in events:
        for status, paths in changes:
            if status == "A" and paths[0] == path:
                found = sha
            elif status.startswith("R") and len(paths) == 2 and paths[1] == path:
                path = paths[0]
    return found


def merged_by_git(git: Git, merges: list, main: str, branch: str, tip, origin_owner):
    """PR 캐시에 그 브랜치의 줄이 없을 때의 머지됨 근거 한 줄, 아니면 None. 조상 관계만으로는 머지됨이 아니다(D1.1).
    머지 메시지 길은 `<owner>` 가 origin 소유자일 때만 센다 — origin_owner 가 None 이면 세지 않는다."""
    sha = _merge_commit_of(git, merges, tip)
    if sha:
        return "기본 브랜치의 머지 커밋 %s" % sha[:8]
    if origin_owner is None:
        return None
    # 머지 메시지가 이 브랜치를 정확히 부른다 — 브랜치가 지워졌거나, 남은 브랜치 끝이 기본 브랜치에 다 들어가
    # 있을 때만(머지 뒤 로컬 브랜치를 기본 브랜치로 앞당긴 경우). 머지 뒤 커밋이 더 붙었으면 머지됨이 아니다.
    if tip and not git.is_ancestor(tip, main):
        return None
    for sha, _parents, subj in merges:
        m = MERGE_MSG_RE.fullmatch(subj.strip())
        if m and m.group(1).casefold() == origin_owner.casefold() and m.group(2) == branch:
            return "머지 메시지 %s (%s)" % (sha[:8], "브랜치 끝이 기본 브랜치에 들어 있음" if tip
                                          else "브랜치는 지워짐")
    return None


def _sh_word(text: str) -> str:
    """셸에 그대로 붙여 넣을 낱말 — 안전한 글자뿐이면 그대로, 아니면 작은따옴표로 감싼다."""
    if re.fullmatch(r"[A-Za-z0-9._/@+=:,-]+", text):
        return text
    return "'" + "'\\''".join(text.split("'")) + "'"


def _judge_pr(rows: list, branch: str, tip_local, tip_remote, default_short, reachable, started=False,
              stale_local=False):
    """(판정 | None, 알림 줄, 고른 줄 | None). 후보는 브랜치 · 머지됨 · 교차 레포 아님 · 기본 브랜치 base 에 맞는 줄만이고
    끝이 있으면 headRefOid 가 끝인 줄만이다 — 캐시의 줄 순서는 판정을 바꾸지 않는다. 끝은 로컬 끝이고, 로컬 끝이 원격 끝의
    조상(stale_local — 받기만 하고 앞당기지 않은 로컬)이면 원격 끝이다. 끝이 없으면 started(이 에픽이
    시작된 흔적 — 지워진 브랜치)일 때만 끝 없이 판정하고, 아니면 아직 만들지 않은 브랜치로 보고 같은 이름의 옛 PR 을 세지 않는다."""
    notes = []
    cands = [r for r in rows if r.get("브랜치") == branch and r.get("상태") == "머지됨"
             and r.get("교차 레포") == "아니오" and r.get("baseRefName") == default_short]
    tip = tip_local or tip_remote
    if tip_local and tip_remote and tip_local != tip_remote:
        if stale_local:
            tip = tip_remote
            notes.append("로컬 끝 %s 이 원격 끝 %s 보다 뒤라 원격 끝으로 판정" % (tip_local[:8], tip_remote[:8]))
        else:
            notes.append("로컬 끝 %s · 원격 끝 %s" % (tip_local[:8], tip_remote[:8]))
    if tip:
        cands = [r for r in cands if r.get("headRefOid") == tip]
    else:
        if cands and not started:
            old_oids = sorted({str(r.get("headRefOid")) for r in cands})
            notes.append("브랜치가 없다 — 같은 이름의 옛 PR %s 은 이 에픽의 PR 로 세지 않았다(이 에픽의 승인된 설계문서나 "
                         "계획이 기본 브랜치에 없어 아직 만들지 않은 브랜치로 본다) — 지운 브랜치면 `git branch %s %s` 로 "
                         "되살리거나, 설계문서의 승인 줄 · 계획의 `**Spec:**` 를 확인한다"
                         % (" · ".join(r.get("번호", "?") for r in cands), _sh_word(branch),
                            old_oids[0] if len(old_oids) == 1 else "<headRefOid>"))
            return None, notes, None
        oids = sorted({r.get("headRefOid") for r in cands})
        if len(oids) > 1:
            notes.append("%s — 같은 이름의 머지된 PR 이 여럿이고 브랜치 끝이 없다(%s) — 브랜치를 맞는 PR 의 headRefOid 로 "
                         "되살린다(`git branch %s <headRefOid>`)"
                         % (PR_UNCOUNTABLE, " · ".join(r.get("번호", "?") for r in cands), branch))
            return PR_UNCOUNTABLE, notes, None
        if oids:
            notes.append("브랜치 끝 없이 판정 — 캐시의 headRefOid %s" % str(oids[0])[:8])
    if not cands:
        return None, notes, None
    known = [r for r in cands if r.get("mergeCommit") not in (None, "", "-")]
    if not known:
        notes.append("PR %s 은 머지됐지만 캐시에 mergeCommit 이 없어 머지됨으로 세지 않았다 — 지휘자를 돌려 PR 캐시를 "
                     "다시 채운다" % " · ".join(r.get("번호", "?") for r in cands))
        return None, notes, None
    hit = next((r for r in known if reachable(r["mergeCommit"])), None)
    if hit is not None:
        return PR_MERGED, notes, hit
    notes.append("%s — %s(PR %s)" % (PR_NOT_FETCHED, FETCH_HINT, known[0].get("번호", "?")))
    return PR_NOT_FETCHED, notes, known[0]


def merged_by_pr(rows: list, branch: str, tip_local, tip_remote, default_short: str, reachable, started=False,
                 stale_local=False):
    """(판정, 알림 줄) — 판정 ∈ 「머지됨」 · 「머지됨(받기 전)」 · 「셀 수 없음」 · None. 여섯 조건: 브랜치 == branch ∧
    상태 == 머지됨 ∧ 교차 레포 == 아니오 ∧ baseRefName == 기본 브랜치 ∧ headRefOid == 끝(로컬, 없으면 원격 — 로컬이
    원격의 조상이면 원격) ∧ mergeCommit 이 기본 ref 에서 닿는다. 끝이 없으면 started(지워진 브랜치)일 때만 다섯으로
    판정하되 맞는 headRefOid 가 둘 이상이면 셀 수 없음 — started 가 아니면 판정 없음과 알림 한 줄."""
    verdict, notes, _row = _judge_pr(rows, branch, tip_local, tip_remote, default_short, reachable, started,
                                     stale_local)
    return verdict, notes


def merged_by_number(number: str, row, branch_rows: list, tip, default_short, reachable, epic: str,
                     roadmap_rel) -> tuple:
    """적은 번호가 있는 브랜치의 판정 — (근거 | None, 정보 줄들, 경고 줄들). 그 번호의 캐시 줄(row)만 본다: 머지됨 ∧ 교차
    레포 아님 ∧ 기본 브랜치 base ∧ mergeCommit 이 기본 ref 에서 닿으면 머지됨. 끝 · 나이 · 이름은 판정에 쓰지 않는다 —
    끝(tip)은 머지 뒤 커밋이 더 붙었는지 알리는 데만 쓴다. 적은 PR 이 머지되지 않았는데 같은 브랜치의 다른 줄이 머지됐으면
    다시 적는 명령을 경고로 보이되 판정은 바꾸지 않는다."""
    if row is None:
        return None, [RECORDED_MISSING % number], []
    if row.get("상태") == "머지됨" and row.get("교차 레포") == "아니오" and row.get("baseRefName") == default_short:
        mc = row.get("mergeCommit")
        if mc in (None, "", "-"):
            return None, ["PR %s 은 머지됐지만 캐시에 mergeCommit 이 없어 머지됨으로 세지 않았다 — 지휘자를 돌려 PR 캐시를 "
                          "다시 채운다" % number], []
        if not reachable(mc):
            return None, [], ["%s — %s(PR %s)" % (PR_NOT_FETCHED, FETCH_HINT, number)]
        infos = []
        head = str(row.get("headRefOid"))
        if tip and tip != head:
            infos.append("머지 뒤 브랜치에 커밋이 더 붙었다(%s ≠ PR 의 head %s — 번호 판정은 그대로)" % (tip[:8], head[:8]))
        return "PR %s 머지됨(적은 번호로 판정 · mergeCommit %s)" % (number, mc[:8]), infos, []
    warns = []
    for other in branch_rows:
        if (other.get("번호") not in (number, "-") and other.get("상태") == "머지됨"
                and other.get("교차 레포") == "아니오" and other.get("baseRefName") == default_short):
            warns.append("적은 PR %s 은 %s이고 같은 브랜치의 PR %s 이 머지됐다 — 그 PR 이 이 에픽의 PR 이면 `ledger pr-record "
                         "--roadmap %s --session <세션> --epic %s --pr %s`"
                         % (number, row.get("상태"), other["번호"],
                            _sh_word(roadmap_rel) if roadmap_rel else "<로드맵>", epic, other["번호"].lstrip("#")))
    return None, [], warns


def read_pr_cache(git: Git, roadmap_rel: str):
    """(PR 캐시 줄들, 에픽 PR 줄들, 못 읽은 사유 | None) — 같은 기계 상태 파일을 한 번 읽는다. 파일이 없으면 ([], [], None)
    — 깨졌으면 빈 캐시로 가고 사유를 낸다. 사유는 끝에 그 사유의 할 일 하나를 단다 — `--reset` 은 옛 판 줄(OldPrRows)의
    할 일일 뿐이다."""
    common = git.common_dir()
    if common is None:
        return [], [], "git 공용 디렉토리를 찾지 못했다 — git 레포 안에서 다시 돌린다"
    try:
        path = machine_path(state_root_for_common(Path(git.cwd, common).resolve()), roadmap_rel)
    except MachineError as exc:
        return [], [], "기계 상태를 읽지 못했다 — %s — 로드맵 경로를 확인한다" % exc
    if path.is_symlink():
        return [], [], "기계 상태 파일이 링크다: %s — 링크를 그 내용의 보통 파일로 바꾼다" % path
    if not path.exists():
        return [], [], None
    if not path.is_file():
        return [], [], "기계 상태 파일이 보통 파일이 아니다: %s — 그 자리에 보통 파일만 둔다" % path
    try:
        data = parse_machine(path.read_text(encoding="utf-8"), roadmap_rel)
    except (OSError, UnicodeDecodeError) as exc:
        return [], [], "기계 상태 파일을 읽지 못했다: %s (%s) — 파일 권한과 UTF-8 인코딩을 확인한다" % (
            path, type(exc).__name__)
    except MachineError as exc:  # 옛 판 줄(--reset) · 판 문장(업데이트 등)은 메시지 끝이 할 일이다
        return [], [], "기계 상태를 읽지 못했다: %s — %s%s" % (
            path, exc, "" if exc.action_in_message else " — 기계 상태 파일에서 그 자리를 고친다")
    return data["PR"], data[EPIC_PR], None


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

    def __init__(self, git: Git, tree: str, specs_dir: str):
        self.git, self.tree, self.specs_dir = git, tree, specs_dir
        self._memo = {}

    def read(self, rel: str):
        return self.git.blob(self.tree, rel)

    def exists(self, rel: str) -> bool:
        return self.git.exists(self.tree, rel)

    def specs_for(self, source: str, specs_dir=None) -> list:
        folder = specs_dir or self.specs_dir
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
            roadmap_rel=None, pr_rows=None, pr_reason=None, default_short=None, epic_pr_rows=None):
    """블록마다 stage · reason · warnings · notes · specs 를 채운다. 반환: 번호 대조 검사 불가 사유 목록.
    roadmap_rel 을 주면 블록에 적힌 브랜치가 모두 머지된 에픽에서 다른 브랜치의 로드맵 사본이 더한 브랜치도 센다.
    머지됨은 브랜치마다 — (블록, 브랜치)에 적은 번호(epic_pr_rows)가 있으면 그 번호의 캐시 줄로만(merged_by_number)
    판정한다. 없으면 PR 캐시(pr_rows)에 그 브랜치의 PR 줄이 하나라도 있으면 merged_by_tips(머지 커밋) 다음 merged_by_pr, 없으면 merged_by_git ·
    결정 기록의 머지 줄로 판정하고, 「PR 0개」 줄(번호 `-` — 지휘자가 PR 이 없다고 확인함)도 없으면 블록에 「PR 상태
    미확인」을 단다. pr_reason(기계 상태 파일이 있는데 못 읽은 사유)이 있으면 번호 기록이 있는지 모르므로 모든 브랜치의
    머지 판정을 보류한다 — 블록은 「알 수 없음」이고 사유에 pr_reason(그 할 일 포함)을 싣는다."""
    merges = git.first_parent_merges(main) if main else []
    extra_cache = []
    no_pr = {r.get("브랜치") for r in pr_rows or [] if r.get("번호") == "-"}  # conductor_state.NO_PR
    pr_rows = [r for r in pr_rows or [] if r.get("번호") != "-"]
    cached = {r.get("브랜치") for r in pr_rows}
    epic_pr_rows = list(epic_pr_rows or [])
    owner_memo = []

    def has_pr(bid, br):
        """PR 캐시에 그 브랜치의 줄이 있거나 (블록, 브랜치)에 적은 번호가 있다 — PR 로 판정하는 브랜치."""
        return br in cached or recorded_number(epic_pr_rows, bid, br) is not None

    def owner():
        """(origin 소유자 | None, 못 읽은 사유 | None) — 처음 필요할 때 한 번 읽는다."""
        if not owner_memo:
            try:
                owner_memo.append((origin_slug(git.cwd)[1], None))
            except GhStop as exc:
                owner_memo.append((None, str(exc)))
        return owner_memo[0]

    started_memo = {}

    def started(block):
        """이 에픽이 시작된 흔적 — 블록의 설계문서가 기본 브랜치에 있고 승인됐거나 그것을 가리키는 계획이 기본 브랜치에
        있다. 끝 없는 브랜치를 PR 로 판정해도 되는지(지워진 브랜치인지 아직 만들지 않은 브랜치인지)를 가른다."""
        if block["id"] not in started_memo:
            specs = find_specs(git, main, block, block["bundle"], settings["specs_dir"])
            when, _why = approval_of(git, main, specs) if specs else (None, None)
            planned = bool(specs) and not when and any(
                plan_specs(git.blob(main, p) or "") & set(specs)
                for s in specs for p in git.grep_files(main, s, settings["plans_dir"]))
            started_memo[block["id"]] = bool(when) or planned
        return started_memo[block["id"]]

    added_memo, events_memo = {}, []

    def doc_added(block):
        """블록의 설계문서(산출물 블록은 산출물)마다 그것을 기본 브랜치 첫째 부모 줄에 처음 더한 커밋 — 문서가 그 에픽
        브랜치와 함께 머지됐으면 그 머지 커밋이다. 이름을 바꾼 문서는 옛 이름의 추가까지 따라간다(first_added).
        기본 브랜치에 없거나 더한 커밋을 못 찾은 문서는 빠진다."""
        if block["id"] not in added_memo:
            if not events_memo:
                rc, log, err = git.run_err("log", "--first-parent", "-M", "--diff-filter=AR", "--name-status",
                                           "--format=%x00%H", main)
                if rc != 0:
                    git.fail("log", rc, err)
                events_memo.append(parse_fp_events(log) if rc == 0 else [])
            added = (first_added(events_memo[0], s)
                     for s in find_specs(git, main, block, block["bundle"], settings["specs_dir"]))
            added_memo[block["id"]] = [a for a in added if a]
        return added_memo[block["id"]]

    def age_ok(block, sha):
        """머지 커밋 sha 를 이 에픽의 머지로 셀 수 있는가 — 거짓: sha 가 그 블록 문서들을 처음 더한 커밋 모두의 엄격한
        조상(그 에픽보다 먼저 머지된 같은 이름의 옛 브랜치). 견줄 커밋이 없으면 None(8.6.0 처럼 센다)."""
        added = doc_added(block)
        if not added:
            return None
        return not all(sha != a and git.is_ancestor(sha, a) for a in added)

    def judge(br, block, extra=False):
        """브랜치 하나의 상태 — tip · merged(근거 | None) · 셀 수 없으면 uncountable. extra(더한 브랜치)는 끝이 없으면
        판정을 쓰지 않으므로 시작 흔적을 묻지 않는다."""
        local = git.commit("refs/heads/" + br)
        remote = git.commit("refs/remotes/origin/" + br)
        st = {"branch": br, "tip": local or remote, "merged": None}
        if pr_reason:
            # 파일은 있는데 못 읽었다 — 번호 기록이 있는지 모르므로 이름 · 이력 추정으로 내려가지 않는다(AC21)
            st["uncountable"] = "%s: %s(%s)" % (br, HOLD, pr_reason)
            return st
        number, row = recorded_cache_row(epic_pr_rows, pr_rows, block["id"], br)
        if number is not None:
            # 적은 번호가 있으면 그 길만 — 머지 커밋 · 나이 · 이름으로 고른 PR 줄 · 머지 메시지를 보지 않는다
            stale = bool(local and remote and local != remote and git.is_ancestor(local, remote))
            merged, infos, warns = merged_by_number(
                number, row, [r for r in pr_rows if r.get("브랜치") == br], remote if stale else (local or remote),
                default_short, lambda c: git.is_ancestor(c, main), block["id"], roadmap_rel)
            block["notes"].extend("%s: %s" % (br, n) for n in infos)
            block["warnings"].extend("%s: %s" % (br, w) for w in warns)
            if merged:
                st["merged"] = merged
                for rev in git.reverts_of(row["mergeCommit"], main):
                    block["warnings"].append("머지 뒤 되돌림 — %s 이 %s 의 머지 커밋 %s 을 되돌렸다(단계는 머지됨 그대로)"
                                             % (rev[:8], br, row["mergeCommit"][:8]))
            return st
        if br not in cached:
            st["merged"] = merged_by_git(git, merges, main, br, st["tip"], owner()[0])
            return st
        st["merged"] = merged_by_tips(git, merges, main, local, remote, lambda sha: age_ok(block, sha))
        if st["merged"]:
            if local and remote and local != remote:
                block["notes"].append("%s: 로컬 끝 %s · 원격 끝 %s" % (br, local[:8], remote[:8]))
            return st
        rows = [r for r in pr_rows if r.get("브랜치") == br]
        stale = bool(local and remote and local != remote and git.is_ancestor(local, remote))
        verdict, notes, hit = _judge_pr(rows, br, local, remote, default_short, lambda c: git.is_ancestor(c, main),
                                        started=extra or bool(local or remote) or started(block) or bool(doc_added(block)),
                                        stale_local=stale)
        if verdict == PR_MERGED and not local and age_ok(block, hit["mergeCommit"]) is False:
            # 로컬이 없으면 끝(원격 ref · 캐시의 headRefOid)이 같은 이름의 옛 브랜치 것일 수 있다 — 문서보다 먼저 머지된 PR 은 세지 않는다
            notes.append("같은 이름의 옛 PR %s 은 이 에픽의 문서가 기본 브랜치에 들어오기 전에 머지돼 이 에픽의 PR 로 세지 "
                         "않았다" % hit.get("번호", "?"))
            verdict, hit = None, None
        if verdict in (PR_NOT_FETCHED, PR_UNCOUNTABLE):
            line = "%s: %s" % (br, notes.pop())
            if verdict == PR_NOT_FETCHED:
                block["warnings"].append(line)
            else:
                st["uncountable"] = line
        block["notes"].extend("%s: %s" % (br, n) for n in notes)
        if verdict == PR_MERGED:
            st["merged"] = "PR %s 머지됨(mergeCommit %s)" % (hit["번호"], hit["mergeCommit"][:8])
            for rev in git.reverts_of(hit["mergeCommit"], main):
                block["warnings"].append("머지 뒤 되돌림 — %s 이 %s 의 머지 커밋 %s 을 되돌렸다(단계는 머지됨 그대로)"
                                         % (rev[:8], br, hit["mergeCommit"][:8]))
        return st

    cache_warning = None
    if pr_reason:
        cache_warning = "PR 캐시를 읽지 못했다 — %s" % pr_reason  # 할 일은 사유마다 read_pr_cache 가 단다

    def unchecked_note(branches, block):
        """캐시 줄이 없는 브랜치에 「PR 상태 미확인」 정보 줄 하나 — 캐시를 못 읽었으면 판정을 보류했으므로 그 줄은
        달지 않고 사유만 경고로."""
        if cache_warning:
            if branches and cache_warning not in block["warnings"]:
                block["warnings"].append(cache_warning)
            return
        unchecked = [br for br in branches if not has_pr(block["id"], br) and br not in no_pr]
        if not unchecked:
            return
        why = ["머지 메시지는 세지 않았다 — %s" % owner()[1]] if owner()[1] else []
        block["notes"].append("%s(%s)" % (PR_UNCHECKED, " · ".join(unchecked + why)))

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
        states = [judge(br, b) for br in b["branches"]]
        b["branch_states"] = states
        unchecked_note([s["branch"] for s in states], b)
        bad = [s["uncountable"] for s in states if s.get("uncountable")]
        if bad:
            b["stage"], b["reason"] = "알 수 없음", " · ".join(bad)
            continue
        rec_merge = rec.get((bid, "머지"))
        if rec_merge and len(states) == 1 and has_pr(bid, states[0]["branch"]):
            if not states[0]["merged"]:
                b["warnings"].append("결정 기록의 머지 줄을 %s 에 적용하지 않았다 — PR 캐시에 그 브랜치의 PR 이 있어 PR 상태로 "
                                     "판정한다" % states[0]["branch"])
            rec_merge = None
        if rec_merge and len(states) > 1 and not all(s["merged"] for s in states):
            # 브랜치가 여럿이면 머지 줄은 쌓인다 — 글에 이름이 적힌 브랜치에만 닿고, 그 ref 가 사라졌을 때만 머지로 센다.
            for s in states:
                if s["merged"]:
                    continue
                line = next((r for r in merge_lines[bid] if names_branch(r["quote"], s["branch"])), None)
                if has_pr(bid, s["branch"]):
                    b["warnings"].append("결정 기록의 머지 줄을 %s 에 적용하지 않았다 — PR 캐시에 그 브랜치의 PR 이 있어 PR "
                                         "상태로 판정한다" % s["branch"])
                elif line is None:
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
            seen_tips = []
            for br in names:
                st = judge(br, b, extra=True)
                if st["tip"]:
                    seen_tips.append(br)   # ref 가 없는 이름은 지웠는지 아직 안 만들었는지 모른다 — 세지 않는다
                if st["tip"] and not st["merged"]:
                    more.append({"branch": br, "tip": st["tip"], "merged": None})
            unchecked_note(seen_tips, b)
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

    names = settings.get("shared_files") or SHARED_BASENAMES
    for b in blocks:
        if b["tip"]:
            for path in git.changed(main, b["tip"]):
                if _shared(path, names):
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


def overlaps(blocks: list, names=SHARED_BASENAMES) -> list:
    reach, out = _reachable(blocks), []
    for i, a in enumerate(blocks):
        for b in blocks[i + 1:]:
            if b["id"] in reach[a["id"]] or a["id"] in reach[b["id"]]:
                continue
            shared = sorted({ea for ea in a["reserved"] for eb in b["reserved"]
                             if not (_shared(ea, names) or _shared(eb, names)) and (_reserves(ea, eb) or _reserves(eb, ea))})
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
    report = {"roadmap": None, "source": None, "read_tree": None, "default_branch": None, "not_on_default": False,
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
        report["read_tree"] = READ_WORKSPACE
        if main is None:
            report["unknown_reasons"].append(git.default_reason or NO_DEFAULT)
    else:
        rel = args.roadmap.strip("/")
        report["roadmap"], report["read_tree"] = rel, READ_DEFAULT
        if main is None:
            report["unknown_reasons"].append(git.default_reason or NO_DEFAULT)
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
    try:   # 해결자는 로드맵 · 레포 설정 파일 · 기본값만 합친다 — 상태 계산이 기계 상태에서 읽는 것은 PR 캐시뿐이다
        resolved = resolve(git.cwd, roadmap=rel, roadmap_text=text)
    except SettingsError as exc:
        resolved = {"values": {"parallel_default": None}, "sources": {}, "warnings": [], "notices": [], "errors": [str(exc)]}
    settings = dict(resolved["values"])
    report["settings"] = dict(settings, sources=resolved["sources"], warnings=resolved["warnings"],
                              notices=resolved["notices"])
    errors = errors + resolved["errors"]
    report["format_errors"] = errors
    if errors:
        report["blocks"] = [{"id": b["id"], "title": b["title"], "kind": b.get("kind"),
                             "stage": "알 수 없음", "reason": "로드맵 형식 깨짐",
                             "task_status": None, "read_tree": report["read_tree"],
                             "branch": field_text(b["fields"].get("브랜치", "")),
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

    pr_rows, epic_pr_rows, pr_reason = read_pr_cache(git, rel)
    cov_unknown = compute(git, main, blocks, records, bundles, roadmap_dir, settings, roadmap_rel=rel,
                          pr_rows=pr_rows, pr_reason=pr_reason, epic_pr_rows=epic_pr_rows,
                          default_short=main_name.split("/", 1)[1] if main_name else None)
    report["unknown_reasons"] += ["번호 대조 검사 불가 — %s" % c for c in cov_unknown]
    report["unknown_reasons"] += ["git 읽기 실패 — %s" % f for f in git.failures]
    report["overlaps"] = overlaps(blocks, settings.get("shared_files") or SHARED_BASENAMES)
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
            "read_tree": READ_TIP if b.get("tip") else READ_DEFAULT,
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
    lines = ["로드맵 상태 — 블록 %d개 · 경고 %d개 · 정보 %d개 · 검사 불가 %d개 (사본: %s · 읽은 트리: %s · 받은 시각: %s)"
             % (len(report["blocks"]), nwarn, ninfo,
                len(report["format_errors"]) + len(report["unknown_reasons"]),
                report["source"] or "알 수 없음", report.get("read_tree") or "알 수 없음",
                report["fetched_at"] or "알 수 없음"),
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
        report = {"roadmap": None, "source": None, "read_tree": None, "default_branch": None, "not_on_default": False,
                  "fetched_at": None, "notice": NOTICE,
                  "blocks": [], "unassigned": None, "orphans": None, "unknown_ids": [],
                  "overlaps": [], "format_errors": [],
                  "unknown_reasons": ["내부 오류 — %s: %s" % (type(exc).__name__, exc)],
                  "settings": None, "handoffs": None, "exit": 3}
    print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else render(report))
    return report["exit"]


if __name__ == "__main__":
    sys.exit(main())
