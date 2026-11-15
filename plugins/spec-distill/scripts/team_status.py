#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_status.py — team 형식 로드맵의 읽기 쪽 모듈. 읽기만 한다.

git 은 받은 `roadmap_status.Git` 으로만 읽는다. `roadmap_status` 는 이 모듈에서 import 하지 않는다.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import branch_tip  # noqa: E402
import job_results  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
from roadmap_model import FormatError, approval_in, field_list, field_text  # noqa: E402

UNPUSHED = "아직 안 올라옴"
SPLIT = "갈라짐"
DESIGN_FLOW, PLAIN_FLOW = "설계 흐름", "설계 없는 흐름"
UNKNOWN = "알 수 없음"
IMPLEMENT = team_layout.STAGES[2]
SHALLOW = "얕은 클론이라 받음 · 진행을 셀 이력이 없다 — `git fetch --unshallow` 뒤 다시 계산한다"


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
    exists_default 는 그 사본에 경로가 있는가 — 주지 않으면 사본에서의 없음을 확인하지 못한 것으로 본다."""

    def __init__(self, git, main, team, read_default, exists_default=None):
        self.git, self.main, self.team, self.read_default = git, main, team, read_default
        self.exists_default = exists_default
        self._shallow = []

    def shallow(self):
        """얕은 클론이면 사유 한 줄, 아니면 None — 한 번만 묻는다. 묻지 못해도 셀 수 없음으로 본다."""
        if not self._shallow:
            rc, out = self.git.run("rev-parse", "--is-shallow-repository")
            self._shallow.append(None if rc == 0 and out.strip() == "false" else
                                 SHALLOW if rc == 0 and out.strip() == "true" else "얕은 클론인지 읽지 못했다")
        return self._shallow[0]

    def read(self, tree, path: str):
        return self.read_default(path) if tree is None else self.git.blob(tree, path)

    def _has(self, tree, path: str) -> bool:
        return self.read_default(path) is not None if tree is None else self.git.exists(tree, path)

    def _absent(self, tree, path: str) -> bool:
        """확인된 없음만 참이다 — 있는데 못 읽음 · git 실패 · 사본을 물을 길 없음은 거짓."""
        if tree is None:
            return self.exists_default is not None and not self.exists_default(path)
        return self.git.absent(tree, path)

    def flow(self, block: dict) -> str:
        return PLAIN_FLOW if "산출물" in block["fields"] else DESIGN_FLOW

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
        결과 파일이 없으면 []. 결과 폴더나 결과 파일을 읽지 못하면 FormatError — 셀 수 없는 것을 [] 로 내지 않는다."""
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
            out += ["- " + line for line in team_files.parse_result(text).rulings]
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

    def progress(self, tip: str, block: dict, plan: int) -> tuple:
        """(단계, 근거, 설계문서들, 계획들) — 브랜치 하나의 끝(tip)에서 그 과제의 단계(설계 §10). plan 은 그 브랜치가
        블록 `브랜치:` 의 몇 번째인가(1 부터). block 의 approved · progress · job 을 채우고 알림을 notes 에 더한다."""
        team, job = self.team, block["id"]
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
                    not any(n.endswith("%s — %s" % (latest, result.problems[0])) for n in notes):
                block["notes"].append("결과 파일을 다 읽지 못했다: %s — %s" % (latest, result.problems[0]))
            if state == job_results.NOT_RECEIVED:
                block["notes"].append("결과 있음 · 받음 없음: %s(%s)" % (
                    latest, "읽지 못함 — 끝 줄이 있는지 모른다" if result is None or lost
                    else "대조를 기다린다" if result.end else "도는 중 — 끝 줄 없음"))
        if plain:
            if unread:
                return "진행 중", "결정 기록 읽기 불가 — %s" % unread, specs, plans
            if state == job_results.RECEIVED:
                return "결과 받음", "결과 받음 줄 있음: %s" % latest, specs, plans
            return "진행 중", "브랜치 있음", specs, plans
        when, why = self._approval(intent)
        block["approved"] = when
        if why:
            return "설계 중", "결정 기록 읽기 불가 — %s" % why, specs, plans
        if not when:
            design = team_layout.DESIGN_FILE
            return "설계 중", ("%s 있음 · spec 승인 줄 없음" % design if specs else "브랜치 있음 · %s 없음" % design), specs, plans
        if latest is None:
            if state == job_results.NOT_COUNTED:   # 결과 폴더를 읽지 못했다 — 「결과 파일 없음」 이라고 하지 않는다
                return UNKNOWN, "%s 를 읽지 못했다" % team.results(job), specs, plans
            return "계획", "spec 승인됨(%s) · %s %s · %s 결과 파일 없음" % (
                when, team_layout.plan_name(plan), "있음" if plans else "없음", IMPLEMENT), specs, plans
        if state == job_results.RECEIVED:
            return "구현 끝", "결과 받음 줄 있음: %s" % latest, specs, plans
        self._fill_progress(block, latest, path, result)
        return "구현 중", "%s 결과 파일 있음: %s" % (IMPLEMENT, latest), specs, plans
