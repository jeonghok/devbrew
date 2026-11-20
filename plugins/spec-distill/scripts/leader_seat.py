#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""leader_seat.py — 리더가 쓰는 자리: 상태 브랜치의 규칙 사본 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄.

명령줄은 `conductor_branch.py` 의 하위 명령(`rules-add` · `rules-drop` · `rules-reset` · `rules-branch`)으로 연다 — 이 모듈은 함수만 둔다.
상태 계산 · 현황 화면은 이 모듈을 가져오지 않는다(`conductor_status.sync` 는 함수 안에서 가져온다).

가져오는 모듈은 `conductor_branch` · `conductor_state` · `team_status` · `team_rules` · `roadmap_model` ·
`roadmap_status`(`Git` 만) · `human_lines` · `repo_defaults` · `state_path` · `team_layout` 뿐이다.

종료 코드(`conductor_branch.BranchError.rc`): 0 썼다 · 쓸 수 없어 알리고 넘어감 · 1 없음/아님(확인되지 않은 남의 고침 ·
재지 못함 · 올릴 규칙 고침이 없음 · 갈라져서 만들지 않은 `rules-branch`) · 2 사용법 · 받지 않는 값 · 3 읽기 불가 · git 실패 ·
5 다른 세션의 표지.
"""
from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path
from typing import NamedTuple, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_branch as CB  # noqa: E402
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_model  # noqa: E402
import state_path  # noqa: E402
import team_rules  # noqa: E402
import team_layout  # noqa: E402
import team_status as TS  # noqa: E402
from roadmap_status import Git  # noqa: E402

RULES_BASE_FILE = TS.RULES_BASE_FILE
BASE_HEAD = "기본 브랜치 커밋: "
FOREIGN = TS.FOREIGN
FOREIGN_UNMEASURED = TS.FOREIGN_UNMEASURED
REFUSE_TAIL = " — confirm 으로 확인받거나 rules-reset 으로 물린다"
NO_COPY = "되돌릴 사본이 없다"
RESET_DONE = "남의 규칙 고침을 물렸다 — 규칙은 기본 브랜치의 글로 돌아갔다"
RESET_PENDING_LEFT = "대기 줄의 남의 고침은 남아 있다 — confirm 하거나 지운다"
RESET_PENDING_UNMEASURED = FOREIGN_UNMEASURED + "(대기 줄) — 확인한 끝은 옮기지 않았다 — confirm 으로 확인받는다"
NOT_TEAM = "team 형식 로드맵이 아니다 — 규칙 사본은 머리말 %s: %s 인 로드맵만 둔다: %s"
NO_STATE_BRANCH = "상태 브랜치가 없다 — 먼저 ensure 를 돌린다"
DIVERGED = "규칙 사본이 기본 브랜치와 갈라졌다"
NOTHING = "올릴 규칙 고침이 없다"
BRANCH_MADE = "규칙 고침 브랜치를 만들었다(올리지 않았다) — %s · %s"
BAD_BRANCH = "규칙 브랜치 이름으로 받지 않는다 — %s"
RULE_REFUSES_BRANCH = "이 레포의 브랜치 규칙이 이 이름을 받지 않는다: %s"
BRANCH_TAKEN = "규칙 브랜치를 만들지 못했다 — 이미 있거나 git 이 받지 않는다"
VERDICTS = ("없음", "같음", "올릴 것", "갈라짐")
_BASE_RE = re.compile(re.escape(BASE_HEAD) + "([0-9a-f]{40})")
_SEGMENT = r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*"
_BRANCH_RE = re.compile(r"(?!.*\.lock(?:/|$))(?!-)" + _SEGMENT + "(?:/" + _SEGMENT + ")*")   # git 이 받는 꼴의 닫힌 부분집합


class RulesState(NamedTuple):
    copy: Optional[str]   # 상태 브랜치의 규칙 사본 글 — 없으면 None
    base: Optional[str]   # rules-base.md 가 적은 기본 브랜치 커밋(40자) — 꼴 밖 · 없음 · 이 레포에 없으면 None
    now: Optional[str]    # 기본 브랜치의 지금 규칙 글 — 없거나 읽지 못하면 None
    verdict: str          # VERDICTS 가운데 하나


def foreign(root, roadmap_rel: str, tip: str, paths: list) -> Optional[list]:
    """`tip` 까지 `paths` 를 바꾼 확인되지 않은 남의 커밋 [(커밋, (경로…)), …]. 기계 상태를 읽지 못하면 None(재지 못함)."""
    try:
        rows = cs.load(cs.machine_path(state_path.state_root(str(root)), roadmap_rel), roadmap_rel)[cs.TRUST]
    except Exception:
        return None
    return TS.foreign_commits(Git(str(root)), tip, TS.trust_of(rows), paths)


def confirm_at(root, roadmap_rel: str, session: str, tip: str) -> tuple:
    """기계 상태 `확인한 끝` 절을 `확인 · <tip>` 한 줄로 둔다. 알릴 줄들을 돌려준다(옛 `## 레포 설정` 절을 지웠으면 그 알림)."""
    path = cs.machine_path(state_path.state_root(str(root)), roadmap_rel)
    old_settings = cs.has_old_repo_settings(path)
    data = cs.load(path, roadmap_rel)
    data[cs.TRUST] = [{"끝": tip, "까닭": cs.TRUST_WHY[0], "때": CB.stamp(), "세션": session}]
    cs.save(path, roadmap_rel, data, session)
    return (cs.OLD_REPO_SETTINGS_DROPPED,) if old_settings else ()


def catch_up(root, name: str, seen: Optional[str]) -> None:
    """로컬 상태 브랜치가 읽을 끝의 조상이면 읽을 끝으로 앞당긴다 — 쓰기(`CB.write`)는 로컬 끝에서 고침을 셈한다.
    받아 오기는 원격 추적 ref 만 옮기므로, 앞당기지 않으면 고침이 남의 끝을 못 보고 「바뀐 것 없음」 으로 끝날 수 있다."""
    local = CB.local_tip(root, name)
    if seen is None or local is None or local == seen:
        return
    rc, out, err = CB.git(root, "rev-list", "-1", "%s..%s" % (seen, local))
    if rc != 0:
        raise CB._git_fail(err, "로컬 상태 브랜치와 읽을 끝을 견주지 못했다")
    if out.strip():   # 로컬에 읽을 끝에 없는 커밋이 있다 — 앞당기지 않는다(올리기가 맞춘다)
        return
    rc, _o, err = CB.git(root, "update-ref", CB.ref_of(name), seen, local)
    if rc != 0:
        raise CB._git_fail(err, "로컬 상태 브랜치를 읽을 끝으로 앞당기지 못했다")


def _need_team(root, roadmap_rel: str, main: str) -> None:
    text = CB.read(root, main, roadmap_rel)
    if text is None:
        raise CB.BranchError(1, "로드맵이 기본 브랜치에 없다: %s" % CB.visible(roadmap_rel))
    if not roadmap_model.is_team(roadmap_model.frontmatter(text)):
        raise CB.BranchError(2, NOT_TEAM % (team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM, CB.visible(roadmap_rel)))


def _check_line(line) -> None:
    """규칙 줄 하나 — 줄을 가르는 글자 · 제어 글자 없이, 규칙 검사가 문제 없는 규칙 하나로 읽는 줄. 아니면 BranchError(2)."""
    if not isinstance(line, str) or not line or "\n" in line or "\r" in line or CB.visible(line) != line:
        raise CB.BranchError(2, "규칙 줄은 줄바꿈 · 제어 글자 없는 한 줄이다: %s" % CB.visible(str(line)))
    rules = team_rules.parse_rules(line + "\n")
    if len(rules) != 1:
        raise CB.BranchError(2, "규칙 줄의 꼴이 아니다(`- [<태그>] <규칙 글> · 출처: … · 확인: …`): %s" % CB.visible(line))
    if rules[0].problems:
        raise CB.BranchError(2, "규칙 줄을 받지 않는다 — %s: %s" % (" · ".join(rules[0].problems), CB.visible(line)))


def _split(text: Optional[str]) -> list:
    """줄 파일의 줄들 — `\\n` 으로만 가른다(다른 줄 가름 글자는 줄 안의 글자로 둔다). 줄 끝의 `\\r` 는 줄에 남긴다 —
    고쳐 쓸 때 다른 줄을 바이트 그대로 두려고. 대조는 `_bare` 로 한다."""
    if not text:
        return []
    lines = text.split("\n")
    if lines[-1] == "":
        lines.pop()
    return lines


def _bare(line: str) -> str:
    """대조할 줄 — 줄 끝의 `\\r` 하나를 벗긴다(CRLF 파일의 줄도 같은 줄로 본다)."""
    return line[:-1] if line.endswith("\r") else line


def _read_tip(root, name: str) -> str:
    """읽을 끝. 상태 브랜치가 갈라졌으면 BranchError(1) 「남의 고침을 재지 못했다 — <사유>」, 없으면 BranchError(1)."""
    seen, split = CB.seen_tip(root, name)
    if seen is None:
        if split:
            raise CB.BranchError(1, "%s — %s" % (FOREIGN_UNMEASURED, CB.visible(split)))
        raise CB.BranchError(1, NO_STATE_BRANCH)
    return seen


def rules_edit(root, roadmap_rel: str, session: str, add: Optional[str] = None, drop: Optional[str] = None,
               reset: bool = False) -> CB.Result:
    """상태 브랜치의 규칙 사본을 줄 하나 더하거나(`add`) 빼거나(`drop`) 사본을 지운다(`reset`).
    사본이 없으면 기본 브랜치 끝의 규칙 글에서 만들고 `rules-base.md` 에 그 커밋을 적는다. `add` · `drop` 은 읽을 끝에서
    규칙 쪽에 확인되지 않은 남의 고침이 있거나 재지 못하면 쓰지 않는다(BranchError(1)). `reset` 은 그 검사 없이 지우고
    (상태 브랜치가 갈라졌으면 셋 모두 쓰지 않는다 — BranchError(1)),
    규칙 쪽에 남의 고침이 있었으면 대기 줄 쪽이 깨끗할 때만 `확인한 끝` 을 새 끝으로 둔다."""
    CB._need_marker(root, roadmap_rel, session)
    why = CB.availability(root, roadmap_rel)
    if why:
        return CB.Result(None, False, None, (why,))
    team = CB.team_of(root, roadmap_rel)
    if [add is not None, drop is not None, bool(reset)].count(True) != 1:
        raise CB.BranchError(2, "add · drop · reset 가운데 하나만 준다")
    main, _short, missing = repo_defaults.default_branch(str(root))
    if main is None:
        raise CB.BranchError(3, missing)
    _need_team(root, roadmap_rel, main)
    base_path = team.path(RULES_BASE_FILE)
    if reset:
        return _reset(root, roadmap_rel, session, team, base_path)
    line = add if add is not None else drop
    _check_line(line)
    seen = _read_tip(root, team.name)
    found = foreign(root, roadmap_rel, seen, TS.rules_paths(team))   # 읽을 끝에서 잰다 — 받아 온 남의 끝이 로컬보다 앞설 수 있다
    if found is None:
        raise CB.BranchError(1, FOREIGN_UNMEASURED + REFUSE_TAIL)
    if found:
        raise CB.BranchError(1, FOREIGN % len(found) + REFUSE_TAIL)
    catch_up(root, team.name, seen)

    def edit(base):
        copy = base.read(team.rules)
        lines = _split(copy if copy is not None else CB.read(root, main, team.rules))
        bare = [_bare(item) for item in lines]
        if add is not None:
            if add in bare:
                raise CB.BranchError(2, "더할 줄이 이미 규칙에 있다: %s" % CB.visible(add))
            crlf = bool(lines) and len(bare) == len([item for item in lines if item.endswith("\r")])
            lines.append(add + "\r" if crlf else add)   # 줄마다 CRLF 인 파일이면 새 줄도 CRLF
        else:
            if drop not in bare:
                raise CB.BranchError(2, "뺄 줄이 규칙에 없다: %s" % CB.visible(drop))
            del lines[bare.index(drop)]
        changes = {team.rules: "".join(item + "\n" for item in lines)}
        if copy is None:
            changes[base_path] = BASE_HEAD + main + "\n"
        return changes

    return CB.write(root, roadmap_rel, session, edit, "규칙 더함" if add is not None else "규칙 뺌")


def _reset(root, roadmap_rel: str, session: str, team, base_path: str) -> CB.Result:
    seen = _read_tip(root, team.name)   # 갈라졌으면 지우지 않는다 — 로컬 끝만 보면 원격의 사본을 「없다」 고 넘긴다
    catch_up(root, team.name, seen)

    def edit(base):
        if base.read(team.rules) is None and base.read(base_path) is None:
            return None
        return {team.rules: None, base_path: None}

    res = CB.write(root, roadmap_rel, session, edit, "규칙 되돌림")
    if res.commit is None:
        return res._replace(notes=res.notes + (NO_COPY,))
    if CB.read(root, res.commit, team.rules) is not None or CB.read(root, res.commit, base_path) is not None:
        return res   # 새 끝에 사본이 남았다 — 그 끝을 확인하지 않는다
    if foreign(root, roadmap_rel, res.commit, TS.rules_paths(team)) == []:
        return res
    pending = foreign(root, roadmap_rel, res.commit, TS.pending_paths(team))
    if pending is None:
        return res._replace(notes=res.notes + (RESET_PENDING_UNMEASURED,))
    if pending:
        return res._replace(notes=res.notes + (RESET_PENDING_LEFT,))
    told = confirm_at(root, roadmap_rel, session, res.commit)
    return res._replace(notes=res.notes + told + (RESET_DONE,))


def _base_commit(root, text: Optional[str]) -> Optional[str]:
    """`rules-base.md` 의 글 → 그 커밋(40자). 한 줄이 `BASE_HEAD + 40자` 와 맞고 그 커밋이 이 레포에 있을 때만 — 아니면 None."""
    lines = _split(text)
    if len(lines) != 1:
        return None
    m = _BASE_RE.fullmatch(lines[0])
    if m is None:
        return None
    rc, _o, _e = CB.git(root, "cat-file", "-e", m.group(1) + "^{commit}")
    return m.group(1) if rc == 0 else None


def _rules_state(root, team, tip: str, main: Optional[str]) -> RulesState:
    copy = CB.read(root, tip, team.rules) if tip else None
    now = CB.read(root, main, team.rules) if main else None
    if copy is None:
        return RulesState(None, None, now, VERDICTS[0])
    base = _base_commit(root, CB.read(root, tip, team.path(RULES_BASE_FILE)))
    if now is not None and now == copy:
        return RulesState(copy, base, now, VERDICTS[1])
    if base is None or now is None or now != CB.read(root, base, team.rules):   # 출발한 글을 모르면 갈라짐으로 닫는다
        return RulesState(copy, base, now, VERDICTS[3])
    return RulesState(copy, base, now, VERDICTS[2])


def rules_state(root, roadmap_rel: str, tip: str) -> RulesState:
    """`tip` 의 규칙 사본과 기본 브랜치의 지금 글. 판정: 사본 없음 「없음」 · 지금 글 == 사본 「같음」 ·
    지금 글 == `rules-base.md` 가 적은 커밋의 글 「올릴 것」 · 그 밖(`rules-base.md` 가 없거나 꼴 밖이거나 그 커밋을 모름) 「갈라짐」.
    남의 글을 읽지만 예외로 죽지 않는다 — 읽지 못한 것은 None 으로 두고 닫는 쪽으로 판정한다."""
    main = repo_defaults.default_branch(str(root))[0]
    return _rules_state(root, CB.team_of(root, roadmap_rel), tip, main)


def _diff_lines(now: Optional[str], copy: Optional[str]) -> list:
    """기본 브랜치의 지금 글 → 사본의 차이 — 줄마다 visible 을 거쳐 「│ 」 를 앞에 붙인다."""
    diff = difflib.unified_diff(_split(now), _split(copy), "기본 브랜치", "규칙 사본", lineterm="")
    return ["│ " + CB.visible(line) for line in diff]


def _check_branch_name(root, branch) -> None:
    """규칙 브랜치 이름 — 상태 브랜치 접두로 시작하지 않고, git 이 받는 꼴의 닫힌 부분집합이고, 레포 규칙 문서가 있으면
    그 정규식이 받아야 한다(`availability` · project-init 훅과 같은 `match` 읽기). 아니면 BranchError(2), 규칙을 읽지 못하면 3."""
    if not isinstance(branch, str) or branch.startswith(team_layout.STATE_BRANCH_PREFIX):
        raise CB.BranchError(2, BAD_BRANCH % CB.visible(str(branch)) + " — %s… 는 상태 브랜치의 자리다" % team_layout.STATE_BRANCH_PREFIX)
    if branch == "HEAD" or _BRANCH_RE.fullmatch(branch) is None:
        raise CB.BranchError(2, BAD_BRANCH % CB.visible(branch))
    kind, value = CB.branch_rule(root)
    if kind == CB.RULE_VERDICTS[2]:
        raise CB.BranchError(3, "%s — %s" % (CB.RULE_UNREADABLE, value))
    if kind == CB.RULE_VERDICTS[1] and not value.match(branch):
        raise CB.BranchError(2, RULE_REFUSES_BRANCH % CB.visible(branch))


def rules_branch(root, roadmap_rel: str, session: str, branch: str) -> str:
    """기본 브랜치 끝 위에 규칙 파일만 상태 브랜치의 사본 글로 바꾼 커밋 하나를 만들어 로컬 브랜치 `branch` 로 둔다.
    올리지 않는다. 만든 커밋(40자)을 돌려준다. 쓸 수 없으면 BranchError(0, 알림). 규칙 쪽에 확인되지 않은 남의 고침이 있거나
    재지 못하면 · 올릴 규칙 고침이 없으면 · 갈라졌으면(둘의 차이를 싣는다) BranchError(1). 이름이 맞지 않으면 2 · 이미 있으면 3."""
    CB._need_marker(root, roadmap_rel, session)
    why = CB.availability(root, roadmap_rel)
    if why:
        raise CB.BranchError(0, why)
    team = CB.team_of(root, roadmap_rel)
    _check_branch_name(root, branch)
    seen = _read_tip(root, team.name)
    found = foreign(root, roadmap_rel, seen, TS.rules_paths(team))
    if found is None:
        raise CB.BranchError(1, FOREIGN_UNMEASURED + REFUSE_TAIL)
    if found:
        raise CB.BranchError(1, FOREIGN % len(found) + REFUSE_TAIL)
    main, _short, missing = repo_defaults.default_branch(str(root))
    if main is None:
        raise CB.BranchError(3, missing)
    state = _rules_state(root, team, seen, main)
    if state.verdict in VERDICTS[:2]:
        raise CB.BranchError(1, NOTHING)
    if state.verdict == VERDICTS[3]:
        raise CB.BranchError(1, "\n".join([DIVERGED] + _diff_lines(state.now, state.copy)))
    commit = CB._build_commit(root, main, {team.rules: state.copy},
                              "chore(conductor): 규칙 고침을 올린다 · 세션 %s" % session[:8], False)
    if commit is None:
        raise CB.BranchError(1, NOTHING)
    rc, _o, err = CB.git(root, "update-ref", "refs/heads/" + branch, commit, CB.ZERO_OID)
    if rc != 0:
        raise CB._git_fail(err, BRANCH_TAKEN)
    return commit
