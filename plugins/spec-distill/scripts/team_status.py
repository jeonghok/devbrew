#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_status.py — team 형식 로드맵의 읽기 쪽 모듈. 읽기만 한다.

git 은 받은 `roadmap_status.Git` 으로 읽고, 브랜치 끝 고르기만 `branch_tip.tip` 이 자기 git 호출로 읽는다(`rev-parse` · `merge-base`).
`roadmap_status` 는 이 모듈에서 import 하지 않는다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import branch_tip  # noqa: E402
import human_lines  # noqa: E402
import job_results  # noqa: E402
import repo_defaults  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
from roadmap_model import FormatError, approval_in, field_list, field_text  # noqa: E402

UNPUSHED = "아직 안 올라옴"
SPLIT = "갈라짐"
DESIGN_FLOW, PLAIN_FLOW = "설계 흐름", "설계 없는 흐름"
UNKNOWN = "알 수 없음"
IMPLEMENT = team_layout.STAGES[2]
SHALLOW = "얕은 클론이라 받음 · 진행을 셀 이력이 없다 — `git fetch --unshallow` 뒤 다시 계산한다"
RESULT_UNREAD, RULINGS_UNREAD = "결과 파일을 다 읽지 못했다", "판정 줄을 다 읽지 못했다"
RESERVE_UNSCANNED = "바꾼 파일의 예약도 재지 않았다"
RECORD_UNREAD = "결정 기록 읽기 불가 — "
NO_RECEIPT, UNREAD_END = "결과 있음 · 받음 없음", "읽지 못함 — 끝 줄이 있는지 모른다"
UNCOUNTED_SHAPE = "세지 않은 결과 파일"
STALE = "묶음 낡음"
STALE_UNMEASURED = STALE + "을 재지 못했다"
FOREIGN = "확인되지 않은 남의 고침 %d"
FOREIGN_UNMEASURED = "남의 고침을 재지 못했다"
TRUST_WHY = ("확인", "씀")   # 기계 상태 `확인한 끝` 절의 까닭 · 칸 — conductor_state 의 것과 같아야 한다(M30)
TRUST_COLUMNS = ("끝", "까닭", "때", "세션")
RULES_BASE_FILE = "rules-base.md"   # 규칙 사본이 출발한 기본 브랜치 커밋을 적는 파일(상태 브랜치의 로드맵 폴더)
PENDING_FILE = "pending.md"   # 상태 브랜치의 대기 줄 파일 — conductor_branch.PENDING_FILE 과 같다
READ_DEFAULT_RULES = " — 규칙은 기본 브랜치의 글을 읽는다"
_OID_RE = re.compile(r"[0-9a-f]{40}")


def read_tip(git, branch: str) -> tuple:
    """(읽을 커밋 | None, 알림 줄 | None, 갈라짐 사유 | None).

    끝 고르기는 branch_tip.tip 하나가 한다. 고른 커밋이 로컬 끝이고 origin 끝과 다르면 올라오지 않은 것이다."""
    try:
        commit, _note = branch_tip.tip(git.cwd, branch)
    except branch_tip.TipError as exc:
        return None, None, "%s — %s" % (SPLIT, exc)
    if commit is None:
        return None, None, None
    local = git.commit("refs/heads/" + branch)
    remote = git.commit("refs/remotes/origin/" + branch)
    if commit == local and commit != remote:
        return commit, ("%s — %s 의 로컬 끝 %s 이 origin 에 없다(로컬을 읽었다)" % (UNPUSHED, branch, commit[:8])), None
    return commit, None, None


def rules_paths(team) -> list:
    """규칙 쪽 남의 고침을 재는 경로 — 규칙 사본과 그 사본이 출발한 커밋 파일(남이 갈라짐 판정을 뒤집지 못하게)."""
    return [team.rules, team.path(RULES_BASE_FILE)]


def pending_paths(team) -> list:
    """대기 줄 쪽 남의 고침을 재는 경로."""
    return [team.path(PENDING_FILE)]


def trust_of(rows):
    """기계 상태 `확인한 끝` 절의 줄들 → (확인 끝 | None, 씀 커밋들의 frozenset).
    기계 상태를 읽지 못함(None) · `확인` 줄이 둘 이상 · 꼴 밖의 줄이면 None(재지 못함)."""
    if rows is None:
        return None
    confirmed, own = [], set()
    for row in rows:
        end, why = row.get(TRUST_COLUMNS[0]), row.get(TRUST_COLUMNS[1])
        if not isinstance(end, str) or not _OID_RE.fullmatch(end):
            return None
        if why == TRUST_WHY[0]:
            confirmed.append(end)
        elif why == TRUST_WHY[1]:
            own.add(end)
        else:
            return None
    if len(confirmed) > 1:
        return None
    return (confirmed[0] if confirmed else None), frozenset(own)


def edits_since(git, tip: str, trust, paths: list):
    """`<확인 끝>..<tip>`(확인 끝이 없으면 tip 의 이력 전부)에서 `paths` 를 바꾼 커밋(`씀` 이든 아니든) —
    [(커밋 40자, (바꾼 경로…)), …] 오래된 차례. 재지 못하면 None: trust 가 None · 확인 끝이 이 레포에 없음 ·
    tip 이 확인 끝을 품지 않음(원격 이력이 다시 쓰여 확인 끝의 조상 · 곁가지로 갔다 — 빈 범위가 「없음」 으로 읽히지 않게) · git 실패 ·
    남의 머지 커밋(경로 한정 log 의 이력 단순화가 그 머지를 숨길 수 있다 — 스크립트는 머지를 만들지 않는다)."""
    if trust is None or not isinstance(tip, str) or not _OID_RE.fullmatch(tip):
        return None
    base, own = trust
    if base is not None and git.commit(base) is None:
        return None
    if base is not None:
        rc, out, _err = git.run_err("log", "--format=%H", "-1", "%s..%s" % (tip, base))
        if rc != 0 or out.strip():
            return None
    rng = "%s..%s" % (base, tip) if base is not None else tip
    rc, out, _err = git.run_err("log", "--format=%H %P", rng)
    if rc != 0:
        return None
    for line in out.splitlines():
        words = line.split()
        if not words or not _OID_RE.fullmatch(words[0]):
            return None
        if len(words) > 2 and words[0] not in own:
            return None
    rc, out = git.changed_by(rng, paths)   # 경로는 레포 뿌리 기준(cwd 가 하위 폴더여도 같다)
    if rc != 0:
        return None
    found = []
    for line in out.splitlines():
        if _OID_RE.fullmatch(line):
            found.append((line, []))
        elif not line:
            continue
        elif found:
            found[-1][1].append(line)
        else:
            return None
    return [(commit, tuple(changed)) for commit, changed in reversed(found)]


def foreign_commits(git, tip: str, trust, paths: list):
    """`edits_since` 가운데 `씀` 에 없는 것 — 확인되지 않은 남의 고침. 재지 못하면 None.
    `씀` 에 든 커밋이 범위에 없어도(버려진 커밋) 그냥 범위 밖이다."""
    found = edits_since(git, tip, trust, paths)
    return None if found is None else [e for e in found if e[0] not in trust[1]]


def own_commits(git, tip: str, trust, paths: list):
    """`edits_since` 가운데 `씀` 에 있는 것 — 이 기계가 쓴 것으로 적힌 고침. 재지 못하면 None."""
    found = edits_since(git, tip, trust, paths)
    return None if found is None else [e for e in found if e[0] in trust[1]]


def rules_tip(git, team, on: bool, rows) -> tuple:
    """(규칙을 읽을 상태 브랜치 끝 | None, 알림들). 꺼짐 · 상태 브랜치 없음 · 사본 없음이면 (None, []).
    갈라졌거나 확인되지 않은 남의 고침이 있거나 재지 못하면 끝 없이 알림 한 줄 — 규칙은 기본 브랜치의 글을 읽는다."""
    if not on:
        return None, []
    try:
        tip, _note = branch_tip.tip(git.cwd, team_layout.STATE_BRANCH_PREFIX + team.name)
    except branch_tip.TipError as exc:
        return None, ["상태 브랜치가 갈라져 규칙은 기본 브랜치의 글을 읽는다 — %s" % exc]
    if tip is None or git.blob(tip, team.rules) is None:
        return None, []
    found = foreign_commits(git, tip, trust_of(rows), rules_paths(team))
    if found is None:
        return None, [FOREIGN_UNMEASURED + READ_DEFAULT_RULES]
    if found:
        return None, [FOREIGN % len(found) + READ_DEFAULT_RULES]
    return tip, []


def outside(team, block: dict, blocks: list, changed: list, shared, reserves) -> list:
    """「예약 밖 변경」 파일들(정렬) — changed 가운데 공유 파일 · 그 과제 폴더 아래 · 어느 블록(그 블록 포함)이 예약한 파일을
    뺀 것(Q13). shared(경로) · reserves(예약, 경로)는 부르는 쪽의 규칙을 받는다 — 같은 규칙을 여기 두 번 쓰지 않는다."""
    job_dir = team.job(block["id"]) + "/"
    owners = [block] + list(blocks)
    return sorted(p for p in changed
                  if not shared(p) and not p.startswith(job_dir)
                  and not any(reserves(e, p) for o in owners for e in o["reserved"]))


class Reader:
    """team 로드맵 블록의 과제 폴더를 읽어 단계를 센다. tree 는 커밋이고, None 이면 로드맵을 읽은 사본(read_default)이다.
    absent_default(경로) 는 그 사본에 그 경로가 없다고 확인됐는가(git 실패는 거짓) — 주지 않으면 사본에서의 없음을
    확인하지 못한 것으로 본다."""

    def __init__(self, git, main, team, read_default, absent_default=None, lead_tip=None):
        self.git, self.main, self.team, self.read_default = git, main, team, read_default
        self.absent_default = absent_default
        self.lead_tip = lead_tip   # 규칙을 읽을 상태 브랜치 끝(rules_tip 이 준 것) — None 이면 기본 브랜치
        self._shallow = []
        self._gate = []

    def shallow(self):
        """얕은 클론이면 사유 한 줄, 아니면 None — 한 번만 묻는다. 묻지 못해도 셀 수 없음으로 본다."""
        if not self._shallow:
            rc, out, err = self.git.run_err("rev-parse", "--is-shallow-repository")
            word = out.strip()
            if rc != 0 or word not in ("true", "false"):   # 묻지 못한 것은 git 읽기 실패로 남긴다(검사 불가 3)
                self.git.fail("rev-parse", rc if rc != 0 else 1, err if rc != 0 else "예상 밖 출력: %s" % (word or "(빈 출력)"))
            self._shallow.append(None if word == "false" and rc == 0 else
                                 SHALLOW if word == "true" and rc == 0 else "얕은 클론인지 읽지 못했다")
        return self._shallow[0]

    def gate_on(self) -> bool:
        """사람 줄 관문이 켜져 있는가 — 처음 불릴 때 레포 설정을 읽어 둔다. 설정을 읽지 못하면 켜진 것이다(J19)."""
        if not self._gate:
            try:
                resolved = repo_defaults.resolve(self.git.cwd)
                self._gate.append(bool(resolved["errors"]) or repo_defaults.gate_on(resolved["values"]))
            except repo_defaults.SettingsError:
                self._gate.append(True)
        return self._gate[0]

    def job_tips(self, branches: list) -> list:
        """그 과제 블록 브랜치들의 끝(read_tip 이 고른 것 — 끝이 없거나 갈라진 브랜치는 뺀다) 뒤에 기본 브랜치 커밋, 겹침 없이."""
        out = []
        for name in branches:
            commit = read_tip(self.git, name)[0]
            if commit and commit not in out:
                out.append(commit)
        if self.main and self.main not in out:
            out.append(self.main)
        return out

    def scope(self, tip: str, job: str, branches: list) -> human_lines.Scope:
        lines, _notes = human_lines.collect(self.git, self.team, job, [tip] + self.job_tips(branches))
        return human_lines.Scope(self.git, self.team, job, tip, lines, self.gate_on())

    def read(self, tree, path: str):
        return self.read_default(path) if tree is None else self.git.blob(tree, path)

    def _has(self, tree, path: str) -> bool:
        return self.read_default(path) is not None if tree is None else self.git.exists(tree, path)

    def _absent(self, tree, path: str) -> bool:
        """확인된 없음만 참이다 — 있는데 못 읽음 · git 실패 · 사본을 물을 길 없음은 거짓."""
        if tree is None:
            return self.absent_default is not None and self.absent_default(path)
        return self.git.absent(tree, path)

    def flow(self, block: dict) -> str:
        """산출물 칸이 있는 블록과 로드맵 밖 과제(kind: task)는 설계 없는 흐름이다(Q5)."""
        return PLAIN_FLOW if "산출물" in block["fields"] or block["kind"] == team_files.KIND_TASK else DESIGN_FLOW

    def _outputs(self, block: dict) -> list:
        return field_list(block["fields"]["산출물"]) if "산출물" in block["fields"] else []

    def specs(self, tree, block: dict) -> list:
        """설계 없는 흐름은 산출물 칸의 경로 가운데 그 트리에 있는 것, 설계 흐름은 과제의 design.md 가 있으면 그 하나."""
        if block["kind"] == "decision":
            return []
        if self.flow(block) == PLAIN_FLOW:
            return [p for p in self._outputs(block) if self._has(tree, p)]
        design = self.team.design(block["id"])
        return [design] if self._has(tree, design) else []

    def _approval(self, intent_text: str) -> tuple:
        try:
            return approval_in(team_files.decision_lines(intent_text)), None
        except FormatError as exc:
            return None, str(exc)

    def approved(self, tree, block: dict) -> tuple:
        """(spec 승인 날짜 | None, 읽기 불가 사유 | None) — 그 트리의 INTENT.md 결정 기록."""
        path = self.team.intent(block["id"])
        text = self.read(tree, path)
        if text is None:
            return None, "%s 를 읽지 못했다" % path
        return self._approval(text)

    def planned(self, tree, block: dict) -> bool:
        """그 트리의 과제 폴더에 계획 파일이 하나라도 있다."""
        if tree is None:
            return False
        names = self.git.names(tree, self.team.job(block["id"]))
        return any(team_layout.plan_number(n) is not None for n in names or [])

    def notices(self, tree, block: dict) -> list:
        """막힘 파일의 알림 줄들 — 단계는 바꾸지 않는다."""
        path = self.team.blocked(block["id"])
        text = self.read(tree, path)
        if text is None:
            return ["막힘 파일을 읽지 못했다: %s — 글을 읽지 못했다" % path] if self._has(tree, path) else []
        b = team_files.parse_blocked(text)
        if b.problems:
            return ["막힘 파일을 읽지 못했다: %s — %s" % (path, b.problems[0])]
        return ["막힘: %s%s 시도 %d — %s" % (b.stage, " plan %d" % b.plan if b.plan else "", b.attempt, path)]

    def drift(self, tree, block: dict) -> list:
        """그 트리의 INTENT.md 목표 · 하지 않을 것 칸이 로드맵 블록의 의도 · 범위와 다른가 — 알림 줄들(AC28)."""
        path = self.team.intent(block["id"])
        text = self.read(tree, path)
        if text is None:
            return ["%s 를 읽지 못했다" % path]
        fields = block["fields"]
        try:
            lines = team_files.intent_drift(text, field_text(fields.get("의도", "")), team_files.scope_line(fields.get("범위", "")))
        except FormatError as exc:
            return ["%s 를 로드맵 블록과 견주지 못했다: %s — %s" % (team_layout.INTENT_FILE, block["id"], exc)]
        return ["%s 가 로드맵 블록과 다르다: %s — %s" % (team_layout.INTENT_FILE, block["id"], line) for line in lines]

    def record_text(self, tree, block: dict) -> str:
        """그 트리의 INTENT.md 결정 기록 칸의 줄들 — 넘김 확인 줄을 읽는 글. INTENT.md 가 없으면(확인된 없음) 빈 글 —
        옛 형식에서 설계문서가 없는 블록과 같다(없음은 drift 의 알림이 알린다). 있는데 읽지 못하면 FormatError."""
        path = self.team.intent(block["id"])
        text = self.read(tree, path)
        if text is None:
            if self._absent(tree, path):
                return ""
            raise FormatError("%s 를 읽지 못했다" % path)
        return "\n".join(team_files.decision_lines(text))

    def rulings(self, tree, block: dict) -> list:
        """그 과제 결과 파일들(이름 순)의 `Ruling:` 줄에 `- ` 를 붙인 것. tree 가 None 이면 기본 브랜치에서 읽는다.
        결과 파일이 없으면 []. 결과 폴더나 결과 파일을 읽지 못하면 FormatError — 셀 수 없는 것을 [] 로 내지 않는다.
        기계 줄을 빠뜨린 결과 파일(lost_lines)은 읽힌 판정 줄을 싣고 block 의 notes 에 알림 한 줄을 더한다 — 같은 파일 ·
        같은 사유를 이미 알렸으면 덧내지 않는다(종료 코드는 그대로)."""
        rev, job = tree or self.main, block["id"]
        if rev is None:
            raise FormatError("기본 브랜치를 몰라 결과 파일을 읽지 못했다")
        names = job_results.result_names(self.git, rev, self.team, job)
        if names is None:
            raise FormatError("%s 를 읽지 못했다" % self.team.results(job))
        out = []
        for name in names:
            stage, plan, attempt = team_layout.parse_result_name(name)
            path = self.team.result(job, stage, attempt, plan)
            text = self.git.blob(rev, path)
            if text is None:
                raise FormatError("%s 를 읽지 못했다" % path)
            result = team_files.parse_result(text)
            lost, notes = team_files.lost_lines(result), block.setdefault("notes", [])
            if lost and not any(job_results.same_fact(n, name, lost[0]) for n in notes if not n.startswith(STALE_UNMEASURED)):
                notes.append(job_results.file_note(RULINGS_UNREAD, name, lost[0]))
            out += ["- " + line for line in result.rulings]
        return out

    def stale(self, tip: str, block: dict) -> list:
        """도는 일꾼(단계 · 계획마다 가장 새 시도이고 끝 줄이 없는 결과 파일)의 묶음이 낡았는가 — 알림 줄들(AC23).
        머리 bundle_at 의 글과 지금 글이 다르면 낡았다(I4). 팀 규칙 파일은 리더가 읽는 ref 에서, 공통 규칙 파일과 그 일꾼의
        역할 문서는 기본 브랜치에서 읽는다. 팀 규칙 파일의 그때 글은 머리 rules_at(상태 브랜치에서 읽은 묶음)에서, 없으면
        bundle_at 에서 읽고, rules_at 커밋이 이 레포에 없으면 재지 못했다고 알린다(R3 AC15).
        머리 bundle_at 이 없거나 꼴이 아니면 재지 못했다고 알리고, 다른 사유로 읽지 못한 파일은 재지 않는다(받음 · 읽지 못함 알림이 따로 있다 — Q13).
        git.blob · git.commit 만 쓴다 — 알림이 종료 코드를 바꾸지 않는다."""
        team, job = self.team, block["id"]
        if self.main is None:
            return []
        names = job_results.result_names(self.git, tip, team, job)
        if not names:
            return []
        parsed = [team_layout.parse_result_name(n) for n in names]
        latest = sorted(job_results.newest(names, stage, plan) for stage, plan in set((p[0], p[1]) for p in parsed))
        out, lead = [], None
        for name in latest:
            stage, plan, attempt = team_layout.parse_result_name(name)
            if team_layout.default_role(stage) is None:   # 검수 결과 파일은 리더가 쓴다 — 받은 묶음이 없다
                continue
            text = self.git.blob(tip, team.result(job, stage, attempt, plan))
            result = team_files.parse_result(text) if text is not None else None
            if result is None:
                if stage != "implement":   # implement 는 받음 · 읽지 못함 알림이 따로 있다(Q13)
                    out.append("%s: %s — 글을 읽지 못했다" % (STALE_UNMEASURED, name))
                continue
            if result.bundle_at is None:   # 머리 값이 없거나 꼴이 아니다 — 잴 묶음이 없다
                if not result.end:
                    why = next((q for q in result.problems if "bundle_at" in q), None)
                    if why is None:   # 머리를 가르지 못한 파일 — 자세한 사유는 받음 · 읽지 못함 알림이 한 번 낸다(Q13)
                        why = "머리를 읽지 못했다" if result.problems else "머리에 bundle_at 이 없다"
                    out.append("%s: %s — %s" % (STALE_UNMEASURED, name, why))
                continue
            if result.problems or team_files.lost_lines(result) or result.end:
                if stage != "implement" and not result.end:   # implement 는 받음 · 읽지 못함 알림이 따로 있다 — 한 사실에 알림 하나(Q13)
                    out.append("%s: %s — %s" % (STALE_UNMEASURED, name, (result.problems + team_files.lost_lines(result))[0]))
                continue
            at = self.git.commit(result.bundle_at)
            if at is None:
                out.append("%s: %s — 묶은 커밋 %s 가 이 레포에 없다" % (STALE_UNMEASURED, name, result.bundle_at[:8]))
                continue
            rules_from = self.git.commit(result.rules_at) if result.rules_at else at
            if rules_from is None:   # 다른 클론이 쓴, 아직 받아 오지 않은 상태 브랜치 커밋 — 지어내지 않는다
                out.append("%s: %s — 규칙을 읽은 커밋 %s 가 이 레포에 없다" % (STALE_UNMEASURED, name, result.rules_at[:8]))
                continue
            if lead is None:
                lead = self.git.commit(team_layout.leader_ref(self.main, self.lead_tip)) or ""
            if not lead:
                out.append("%s: %s — 팀 규칙을 읽을 커밋이 없다" % (STALE_UNMEASURED, name))
                continue
            roadmaps_dir = team.roadmaps_dir
            checks = [(team.rules, rules_from, lead), (team_layout.handbook(roadmaps_dir), at, self.main),
                      (team_layout.role_doc(roadmaps_dir, result.role), at, self.main)]
            changed = [path for path, then, rev in checks if self.git.blob(then, path) != self.git.blob(rev, path)]
            if changed:
                out.append("%s: %s — 묶은 커밋 %s 뒤에 바뀜: %s" % (STALE, name, at[:8], " · ".join(changed)))
        return out

    def _fill_progress(self, block: dict, name: str, path: str, result) -> None:
        if result is None:
            block["progress"] = {"done": None, "total": None, "why": "%s 를 읽지 못했다" % path}
            return
        lost = team_files.lost_lines(result)
        if lost:   # 빠뜨린 기계 줄이 있으면 남은 줄로 센 수는 수가 아니다
            block["progress"] = {"done": None, "total": None, "why": "결과 파일을 다 읽지 못했다 — %s" % lost[0]}
            return
        done, total, why = team_files.progress_of(result)
        if why is None:
            block["progress"] = {"done": done, "total": total}
            return
        block["progress"] = {"done": None, "total": None, "why": why}
        broken = team_files.PROGRESS_BROKEN + " — "
        if why.startswith(broken):
            block["notes"].append("진행 줄을 믿지 않았다: %s — %s" % (name, why[len(broken):]))

    def shape_notes(self, tip: str, block: dict, number, plain: bool) -> list:
        """implement 결과 파일 이름의 계획 번호가 흐름과 다르면 세지 않았다고 알린다 — 단계 · 근거는 그대로다."""
        names = job_results.result_names(self.git, tip, self.team, block["id"]) or []
        flow = PLAIN_FLOW if plain else DESIGN_FLOW
        out = []
        for name in names:
            stage, named, attempt = team_layout.parse_result_name(name)
            if stage == IMPLEMENT and (named is None) != plain:
                out.append("%s: %s — %s 의 %s 결과 파일은 %s 이다" % (
                    UNCOUNTED_SHAPE, name, flow, IMPLEMENT, team_layout.result_name(stage, attempt, number)))
        return out

    def progress(self, tip: str, block: dict, plan: int) -> tuple:
        """(단계, 근거, 설계문서들, 계획들) — 브랜치 하나의 끝(tip)에서 그 과제의 단계(설계 §10). plan 은 그 브랜치가
        블록 `브랜치:` 의 몇 번째인가(1 부터). block 의 approved · progress · job 을 채우고 알림을 notes 에 더한다."""
        team, job = self.team, block["id"]
        if not self.gate_on():   # 도는 과제마다 첫 알림 줄(J10) — 흐름을 가르기 전에
            notes = block.setdefault("notes", [])
            if human_lines.GATE_OFF not in notes:
                notes.insert(0, human_lines.GATE_OFF)
        plain = self.flow(block) == PLAIN_FLOW
        number = None if plain else plan
        intent_path = team.intent(job)
        block.update(approved=None, progress=None, job={"intent": intent_path, "plan": number, "result": None})
        specs = self.specs(tip, block)
        plans = [] if plain or not self._has(tip, team.plan(job, plan)) else [team.plan(job, plan)]
        block["notes"].extend(self.notices(tip, block))   # 막힘은 단계를 셀 수 없을 때도 알린다
        shallow = self.shallow()
        if shallow:
            return UNKNOWN, shallow, specs, plans
        intent = self.read(tip, intent_path)
        if intent is None:
            return UNKNOWN, "%s 를 읽지 못했다" % intent_path, specs, plans
        block["notes"].extend(self.stale(tip, block))
        block["notes"].extend(self.shape_notes(tip, block, number, plain))
        try:
            state, notes, latest = job_results.receipt(self.git, self.main, tip, team, job, intent, IMPLEMENT, number,
                                                       block["reserved"], self._outputs(block))
            unread = None
        except FormatError as exc:   # 결정 기록 칸을 찾지 못했다 — 받음 줄을 셀 수 없다(결과 파일 이름은 따로 구한다)
            state, notes, unread = None, [], str(exc)
            latest = job_results.newest(job_results.result_names(self.git, tip, team, job) or [], IMPLEMENT, number)
        block["job"]["result"] = latest
        block["notes"].extend(notes)
        result = path = None
        if latest:
            parsed = team_layout.parse_result_name(latest)
            path = team.result(job, parsed[0], parsed[2], parsed[1])
            text = self.read(tip, path)
            result = team_files.parse_result(text) if text is not None else None
            lost = team_files.lost_lines(result) if result is not None else []
            # 받음 줄의 대조(receipt)가 이 파일의 같은 사유를 이미 알렸으면 한 번만 낸다(Q13 — 한 사실에 알림 하나)
            if result is not None and result.problems and \
                    not any(job_results.same_fact(n, latest, result.problems[0]) for n in notes):
                block["notes"].append(job_results.file_note(RESULT_UNREAD, latest, result.problems[0]))
            if state == job_results.NOT_RECEIVED:
                block["notes"].append("%s: %s(%s)" % (
                    NO_RECEIPT, latest, UNREAD_END if result is None or lost
                    else "대조를 기다린다" if result.end else "도는 중 — 끝 줄 없음"))
        if plain:
            running, received = team_layout.PLAIN_FLOW_STAGES
            if unread:
                return running, RECORD_UNREAD + unread, specs, plans
            if state == job_results.RECEIVED:
                return received, "결과 받음 줄 있음: %s" % latest, specs, plans
            return running, "브랜치 있음", specs, plans
        _when, why = self._approval(intent)
        if why:
            block["approved"] = None
            return "설계 중", RECORD_UNREAD + why, specs, plans
        got, no = human_lines.passed(self.scope(tip, job, block.get("branches") or []), human_lines.KIND_SPEC, None, deep=False)
        when = got.date if got else None
        block["approved"] = when
        if got is None:
            design = team_layout.DESIGN_FILE
            if no != human_lines.NO_LINE:
                return "설계 중", "%s 있음 · spec 승인 줄이 지나지 못했다 — %s" % (design, no), specs, plans
            return "설계 중", ("%s 있음 · spec 승인 줄 없음" % design if specs else "브랜치 있음 · %s 없음" % design), specs, plans
        word = "승인 건너뜀" if got.skipped else "승인됨"   # 건너뜀 줄로 지났으면 근거의 앞머리가 다르다
        if latest is None:
            if state == job_results.NOT_COUNTED:   # 결과 폴더를 읽지 못했다 — 「결과 파일 없음」 이라고 하지 않는다
                return UNKNOWN, "%s 를 읽지 못했다" % team.results(job), specs, plans
            return "계획", "spec %s(%s) · %s %s · %s 결과 파일 없음" % (
                word, when, team_layout.plan_name(plan), "있음" if plans else "없음", IMPLEMENT), specs, plans
        if state == job_results.RECEIVED:
            return "구현 끝", "결과 받음 줄 있음: %s" % latest, specs, plans
        self._fill_progress(block, latest, path, result)
        return "구현 중", "%s 결과 파일 있음: %s" % (IMPLEMENT, latest), specs, plans


# ── 머지된 계획(J11) ─────────────────────────────────────────────────────────

NOT_COUNTED_AS_MERGED = "상태 보기는 이 브랜치를 머지로 세지 못한다"


def plan_merged(reader, block: dict, n: int) -> tuple:
    """(머지 근거 | None, 셀 수 없는 사유 | None) — 블록의 n 번째 계획(설계 없는 흐름은 첫째 브랜치)의 브랜치가 머지됐는가.

    상태 보고의 branch_states 를 쓰고, 끝이 로컬에도 origin 에도 없는데 기본 브랜치에 그 계획의 자취(설계 흐름은 계획 파일,
    설계 없는 흐름은 implement 결과 파일)가 있으면 머지돼 지워진 것으로 읽는다 — 이 갈래는 상태 보기가 머지로 세지 못한다.

    block 은 상태 보고의 블록에 로드맵 블록의 `fields` 를 더한 것이다(흐름을 가르는 데 Reader.flow 가 쓴다)."""
    states = block.get("branch_states") or []
    if n < 1 or n > len(states):
        return None, None
    state = states[n - 1]
    if state.get("uncountable"):
        return None, state["uncountable"]
    if state.get("merged"):
        return state["merged"], None
    if state.get("tip") is not None or not reader.main:
        return None, None
    job, team, git = block["id"], reader.team, reader.git
    if reader.flow(block) == PLAIN_FLOW:
        names = job_results.result_names(git, reader.main, team, job)
        if names is None:
            return None, "기본 브랜치의 결과 폴더를 읽지 못했다: %s" % team.results(job)
        trace = [team.job(job, team_layout.RESULTS_DIR, x) for x in names
                 if team_layout.parse_result_name(x)[0] == IMPLEMENT]
        path = trace[0] if trace else None
    else:
        path = team.plan(job, n)
        if not git.exists(reader.main, path):
            if not git.absent(reader.main, path):
                return None, "기본 브랜치의 %s 를 읽지 못했다" % path
            path = None
    if path is None:
        return None, None
    return "브랜치는 없고 기본 브랜치에 %s 가 있다 — %s" % (path, NOT_COUNTED_AS_MERGED), None


# ── 로드맵 밖 과제(kind: task) ───────────────────────────────────────────────

OUTSIDE = "로드맵 밖 과제"
MERGED, ON_DEFAULT = "머지됨", "기본 브랜치에 있음"
TASKS_UNCOUNTED, TASKS_PARTLY = OUTSIDE + "를 세지 못했다", OUTSIDE + "를 다 세지 못했다"   # 하나도 못 셈 · 읽은 것만 셈
MAIN_JOBS_UNREAD = "기본 브랜치의 %s 를 읽지 못했다"


def _intent_head(git, rev: str, path: str) -> tuple:
    """(글 | None, 머리 | None, 세지 못한 사유 | None) — 그 커밋의 INTENT.md. 확인된 없음은 (None, None, None)이고
    있는데 못 읽음 · git 실패 · 머리 깨짐은 사유를 낸다."""
    text = git.blob(rev, path)
    if text is None:
        return None, None, None if git.absent(rev, path) else "%s 를 읽지 못했다" % path
    try:
        return text, team_files.intent_meta(text), None
    except FormatError as exc:
        return None, None, "%s 머리를 읽지 못했다 — %s" % (path, exc)


def _head_paths(value: str) -> list:
    """머리 `paths: [a, b]` 의 값 → 경로들."""
    value = value.strip()
    if value.startswith("[") and value.endswith("]"):
        value = value[1:-1]
    return [p.strip() for p in value.split(",") if p.strip()]


def _title(text: str):
    """목표 칸의 첫 줄 — 칸을 찾지 못하면 None."""
    try:
        return team_files.intent_sections(text)["목표"].split("\n")[0]
    except FormatError:
        return None


def _job(team, name: str, text: str, meta: dict, stage: str, reason: str, tip, block=None) -> dict:
    """과제 하나. task_status 는 부르는 쪽이 단계 글자 표로 채운다(그 표는 roadmap_status 에 하나 있다)."""
    return {"id": name, "kind": team_files.KIND_TASK, "title": _title(text), "stage": stage, "reason": reason,
            "task_status": None, "branch": meta.get("branch", ""), "tip": tip, "intent": team.intent(name),
            "progress": block.get("progress") if block else None, "notes": block["notes"] if block else []}


def task_jobs(reader, blocks: list, scan=None) -> tuple:
    """(과제 목록, 알림 줄 목록) — 로드맵 블록이 아닌 과제 폴더 가운데 INTENT.md 머리의 kind 가 task 인 것(AC14).
    scan(과제) 은 브랜치 끝에서 센 과제(`id` · `tip` · 머리 paths 인 `reserved`)의 예약 알림 줄들을 내고 그 과제의 notes 에
    붙는다 — 판정은 부르는 쪽이 블록과 같은 것을 준다. 기본 브랜치에 있는 과제(머지됨)는 잴 브랜치가 없어 부르지 않는다.

    기본 브랜치에 있으면 「머지됨」. 기본 브랜치에 들어가지 않은 브랜치 끝(Git.unmerged_tips)에서 찾은 과제는 머리
    `branch` 가 가리키는 브랜치의 끝(read_tip)에서 다시 읽어, 같은 폴더가 있고 머리가 그 이름일 때만 센다 — 다른 브랜치의
    사본은 같은 짝이라 한 번만 세어진다(Q2). 단계 · 알림 · 진행 칸은 블록과 같은 Reader.progress 가 채운다(설계 없는 흐름 —
    진행 중 · 결과 받음, Q12). 갈라진 브랜치는 싣지 않고 알림만(Q10). 세지 못한 것도 알림으로 — 없음으로 내지 않는다. git 이 읽지 못한 것은
    git.failures 에도 남아 부르는 쪽(build)이 검사 불가로 올린다."""
    git, main, team = reader.git, reader.main, reader.team
    if main is None:
        return [], ["%s — 기본 브랜치를 모른다" % TASKS_UNCOUNTED]
    on_main = git.names(main, team.jobs)
    if on_main is None:
        return [], ["%s — %s" % (TASKS_UNCOUNTED, MAIN_JOBS_UNREAD % team.jobs)]
    taken = set(str(b["id"]).casefold() for b in blocks)
    jobs, notes = [], []

    def note(line):
        if line not in notes:
            notes.append(line)

    def uncounted(name, why):
        note("%s %s 을 세지 못했다 — %s" % (OUTSIDE, name, why))

    known = set()
    for name in on_main:
        if name.casefold() in taken:
            continue
        known.add(name)
        text, meta, why = _intent_head(git, main, team.intent(name))
        if why:
            uncounted(name, why)
        elif meta is not None and meta.get("kind") == team_files.KIND_TASK:
            jobs.append(_job(team, name, text, meta, MERGED, ON_DEFAULT, None))
    pairs = set()
    failed_before = len(git.failures)
    tips = git.unmerged_tips(main)
    if len(git.failures) > failed_before:
        note("%s — 기본 브랜치에 들어가지 않은 브랜치 끝을 읽지 못했다" % TASKS_PARTLY)
    for tip in tips:
        names = git.names(tip, team.jobs)
        if names is None:
            note("%s — 브랜치 끝 %s 의 %s 를 읽지 못했다" % (TASKS_PARTLY, tip[:8], team.jobs))
            continue
        for name in names:
            if name.casefold() in taken or name in known:
                continue
            _text, meta, why = _intent_head(git, tip, team.intent(name))
            if why:
                uncounted(name, why)
            elif meta is not None and meta.get("kind") == team_files.KIND_TASK:
                pairs.add((name, meta.get("branch", "")))
    for name, branch in sorted(pairs):
        if not branch:
            note("%s %s 을 세지 않았다 — 머리에 branch 가 없다" % (OUTSIDE, name))
            continue
        tip, tip_note, split = read_tip(git, branch)
        if split:
            note("%s %s: %s" % (OUTSIDE, name, split))
            continue
        text, meta, why = _intent_head(git, tip, team.intent(name)) if tip else (None, None, None)
        if why:   # 폴더는 있는데 INTENT.md 를 읽지 못했다 — 「폴더가 없다」 가 아니라 그 사유를 낸다
            uncounted(name, why)
            continue
        if meta is None or meta.get("branch") != branch:
            note("%s %s 을 세지 않았다 — 머리의 branch(%s) 와 이름이 맞는 브랜치에 이 과제 폴더가 없다" % (OUTSIDE, name, branch))
            continue
        block = {"id": name, "kind": team_files.KIND_TASK, "fields": {}, "reserved": _head_paths(meta.get("paths", "")),
                 "notes": [tip_note] if tip_note else []}
        stage, reason, _specs, _plans = reader.progress(tip, block, 1)
        if scan is not None:
            if reader.shallow() == SHALLOW:   # 얕은 클론은 merge base 도 잘려 diff 가 실패한다 — 예약을 재지 않는다
                reason = "%s · %s" % (reason, RESERVE_UNSCANNED)
            else:
                block["notes"].extend(scan(dict(block, tip=tip)))
        if reason.startswith(RECORD_UNREAD):   # 단계는 블록과 같게 두되 결과 받음일 수 있음을 알린다
            note("%s %s: %s 의 결정 기록을 읽지 못해 결과 받음인지 셀 수 없다 — %s"
                 % (OUTSIDE, name, team.intent(name), reason[len(RECORD_UNREAD):]))
        jobs.append(_job(team, name, text, meta, stage, reason, tip, block))
    branches = {}
    for j in jobs:
        branches.setdefault(j["id"], []).append(j["branch"])
    for name in sorted(branches):
        if len(branches[name]) > 1:
            note("%s 이름이 겹친다: %s — %s" % (OUTSIDE, name, " · ".join(sorted(branches[name]))))
    return sorted(jobs, key=lambda j: (j["id"], j["branch"])), notes
