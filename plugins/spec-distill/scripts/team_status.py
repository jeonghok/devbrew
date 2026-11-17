#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_status.py — team 형식 로드맵의 읽기 쪽 모듈. 읽기만 한다.

git 은 받은 `roadmap_status.Git` 으로 읽고, 브랜치 끝 고르기만 `branch_tip.tip` 이 자기 git 호출로 읽는다(`rev-parse` · `merge-base`).
`roadmap_status` 는 이 모듈에서 import 하지 않는다.
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
RESULT_UNREAD, RULINGS_UNREAD = "결과 파일을 다 읽지 못했다", "판정 줄을 다 읽지 못했다"
RESERVE_UNSCANNED = "바꾼 파일의 예약도 재지 않았다"
RECORD_UNREAD = "결정 기록 읽기 불가 — "
NO_RECEIPT, UNREAD_END = "결과 있음 · 받음 없음", "읽지 못함 — 끝 줄이 있는지 모른다"
UNCOUNTED_SHAPE = "세지 않은 결과 파일"
STALE = "묶음 낡음"
STALE_UNMEASURED = STALE + "을 재지 못했다"


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
    absent_default(경로) 는 그 사본에 그 경로가 없다고 확인됐는가(git 실패는 거짓) — 주지 않으면 사본에서의 없음을
    확인하지 못한 것으로 본다."""

    def __init__(self, git, main, team, read_default, absent_default=None):
        self.git, self.main, self.team, self.read_default = git, main, team, read_default
        self.absent_default = absent_default
        self._shallow = []

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
            if lost and not any(job_results.same_fact(n, name, lost[0]) for n in notes):
                notes.append(job_results.file_note(RULINGS_UNREAD, name, lost[0]))
            out += ["- " + line for line in result.rulings]
        return out

    def stale(self, tip: str, block: dict) -> list:
        """도는 일꾼(단계 · 계획마다 가장 새 시도이고 끝 줄이 없는 결과 파일)의 묶음이 낡았는가 — 알림 줄들(AC23).
        머리 bundle_at 의 글과 지금 글이 다르면 낡았다(I4). 팀 규칙 파일은 리더가 읽는 ref 에서, 공통 규칙 파일과 그 일꾼의
        역할 문서는 기본 브랜치에서 읽는다. 머리 bundle_at 이 없거나 꼴이 아니면 재지 못했다고 알리고, 다른 사유로 읽지 못한 파일은 재지 않는다(받음 · 읽지 못함 알림이 따로 있다 — Q13).
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
                continue
            if result.bundle_at is None:   # 머리 값이 없거나 꼴이 아니다 — 잴 묶음이 없다
                if not result.end:
                    why = next((q for q in result.problems if "bundle_at" in q), None)
                    if why is None:   # 머리를 가르지 못한 파일 — 자세한 사유는 받음 · 읽지 못함 알림이 한 번 낸다(Q13)
                        why = "머리를 읽지 못했다" if result.problems else "머리에 bundle_at 이 없다"
                    out.append("%s: %s — %s" % (STALE_UNMEASURED, name, why))
                continue
            if result.problems or team_files.lost_lines(result) or result.end:
                continue   # 다른 사유로 읽지 못한 파일은 받음 · 읽지 못함 알림(Q13)이 알린다 — 한 사실에 알림 하나
            at = self.git.commit(result.bundle_at)
            if at is None:
                out.append("%s: %s — 묶은 커밋 %s 가 이 레포에 없다" % (STALE_UNMEASURED, name, result.bundle_at[:8]))
                continue
            if lead is None:
                lead = self.git.commit(team_layout.leader_ref(self.main)) or ""
            if not lead:
                out.append("%s: %s — 팀 규칙을 읽을 커밋이 없다" % (STALE_UNMEASURED, name))
                continue
            roadmaps_dir = team.roadmaps_dir
            checks = [(team.rules, lead), (team_layout.handbook(roadmaps_dir), self.main),
                      (team_layout.role_doc(roadmaps_dir, result.role), self.main)]
            changed = [path for path, rev in checks if self.git.blob(at, path) != self.git.blob(rev, path)]
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
        when, why = self._approval(intent)
        block["approved"] = when
        if why:
            return "설계 중", RECORD_UNREAD + why, specs, plans
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
