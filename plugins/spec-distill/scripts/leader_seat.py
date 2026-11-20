#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""leader_seat.py — 리더가 쓰는 자리: 상태 브랜치의 규칙 사본 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄.

명령줄은 `conductor_branch.py` 의 하위 명령(`rules-add` · `rules-drop` · `rules-reset` · `rules-branch` · `confirm`)으로 연다 — 이 모듈은 함수만 둔다.
대기 줄(`pending.md`)은 `conductor_ledger.py` 의 `add` · `drop` · `pending` · `flush` 가 함수 안에서 가져와 부른다.
상태 계산 · 현황 화면은 이 모듈을 가져오지 않는다(`conductor_status.sync` 는 함수 안에서 가져온다).

가져오는 모듈은 `conductor_branch` · `conductor_state` · `team_status` · `team_rules` · `roadmap_model` ·
`roadmap_status`(`Git` 만) · `repo_defaults` · `state_path` · `team_layout` 뿐이다.

종료 코드(`conductor_branch.BranchError.rc`): 0 썼다 · 쓸 수 없어 알리고 넘어감 · 1 없음/아님(확인되지 않은 남의 고침 ·
재지 못함 · 올릴 규칙 고침이 없음 · 갈라져서 만들지 않은 `rules-branch` · 확인 없이 부른 `confirm`) · 2 사용법 · 받지 않는 값 · 3 읽기 불가 · git 실패 ·
5 다른 세션의 표지.
"""
from __future__ import annotations

import collections
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
CONFIRM_TIP = "확인할 끝: %s"
CONFIRM_HOW = " — 차이를 보고 사용자 확인 뒤 --confirmed <확인할 끝 40자> 를 붙여 다시 부른다"
NOTHING_TO_CONFIRM = "확인할 남의 고침이 없다"
CONFIRMED = "확인한 끝을 기록했다 — %s"
NOT_THE_TIP = "확인할 끝이 아니다 — 지금 끝에서 다시 셌다"
RECOUNTED = " — 확인한 끝 없이 이력 전부에서 다시 셌다: "
UNWRITTEN = " — 이 기계가 쓰지 않은 커밋 %d 을 모두 보인다"
MERGE_MARK = "머지 커밋 · 부모 %d"
OWN_ROWS_MAX = 500   # 「씀」 줄이 이보다 많으면 알린다 — 기계 상태 크기 한도(1 MiB) 앞에서(S13)
LONG_FOREIGN = "확인되지 않은 남의 고침이 오래 남아 있다 — confirm 하거나 지운다"
PENDING_NO_BRANCH = "상태 브랜치가 없어 기계 상태에 쌓았다 — ensure 뒤의 줄부터 상태 브랜치에 쌓는다"
PENDING_HUMAN = "사람 줄이라 옮기지 않은 대기 줄 %d — record --human 으로 적고 drop 으로 지운다"
PENDING_FOREIGN = "확인되지 않은 남의 고침이 더한 대기 줄 %d — 옮기지 않았다"
PENDING_UNCONFIRMED_TAIL = "   (확인되지 않은 남의 고침)"
PENDING_COLUMNS = cs.COLUMNS["쌓인 기록"]   # 에픽 · 절 · 글 — 기계 상태 줄과 같은 꼴
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


def catch_up(root, name: str, seen: Optional[str]) -> tuple:
    """로컬 상태 브랜치가 읽을 끝의 조상이면 읽을 끝으로 앞당긴다 — 쓰기(`CB.write`)는 로컬 끝에서 고침을 셈한다.
    받아 오기는 원격 추적 ref 만 옮기므로, 앞당기지 않으면 고침이 남의 끝을 못 보고 「바뀐 것 없음」 으로 끝날 수 있다.
    옮겼으면 알릴 줄 하나(`CB.ELSEWHERE` — 올리기가 거절돼 다시 만들 때와 같은 꼴), 아니면 빈 튜플. 옮긴 끝은 「씀」 이 아니다."""
    local = CB.local_tip(root, name)
    if seen is None or local is None or local == seen:
        return ()
    rc, out, err = CB.git(root, "rev-list", "-1", "%s..%s" % (seen, local))
    if rc != 0:
        raise CB._git_fail(err, "로컬 상태 브랜치와 읽을 끝을 견주지 못했다")
    if out.strip():   # 로컬에 읽을 끝에 없는 커밋이 있다 — 앞당기지 않는다(올리기가 맞춘다)
        return ()
    rc, _o, err = CB.git(root, "update-ref", CB.ref_of(name), seen, local)
    if rc != 0:
        raise CB._git_fail(err, "로컬 상태 브랜치를 읽을 끝으로 앞당기지 못했다")
    return (CB.ELSEWHERE % (seen[:8], CB._commit_stamp(root, seen)),)


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


def _writable_tip(root, roadmap_rel: str, team, guard: Optional[list] = None) -> tuple:
    """(읽을 끝, 앞당긴 알림) — 쓰기 앞의 걸음. 갈라졌거나 없으면 BranchError(1)(`_read_tip`). `guard` 경로를 주면 읽을 끝에서
    그 쪽에 확인되지 않은 남의 고침이 있거나 재지 못할 때 쓰지 않는다(BranchError(1)). 그 뒤 로컬 끝을 읽을 끝으로 앞당긴다
    (`catch_up` — 받아 온 남의 끝이 로컬보다 앞설 수 있다)."""
    seen = _read_tip(root, team.name)
    if guard is not None:
        found = foreign(root, roadmap_rel, seen, guard)
        if found is None:
            raise CB.BranchError(1, FOREIGN_UNMEASURED + REFUSE_TAIL)
        if found:
            raise CB.BranchError(1, FOREIGN % len(found) + REFUSE_TAIL)
    return seen, catch_up(root, team.name, seen)


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
    _seen, moved = _writable_tip(root, roadmap_rel, team, TS.rules_paths(team))   # 읽을 끝에서 잰다

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

    res = CB.write(root, roadmap_rel, session, edit, "규칙 더함" if add is not None else "규칙 뺌")
    return res._replace(notes=moved + res.notes)


def _reset(root, roadmap_rel: str, session: str, team, base_path: str) -> CB.Result:
    _seen, moved = _writable_tip(root, roadmap_rel, team)   # 갈라졌으면 지우지 않는다 — 로컬 끝만 보면 원격의 사본을 「없다」 고 넘긴다

    def edit(base):
        if base.read(team.rules) is None and base.read(base_path) is None:
            return None
        return {team.rules: None, base_path: None}

    res = CB.write(root, roadmap_rel, session, edit, "규칙 되돌림")
    res = res._replace(notes=moved + res.notes)   # 앞당긴 알림이 먼저다 — 아래 갈래의 알림은 뒤에 붙는다
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


def _diff(before: Optional[str], after: Optional[str], a: str, b: str) -> list:
    """before → after 의 차이 — 줄마다 visible 을 거쳐 「│ 」 를 앞에 붙인다."""
    return ["│ " + CB.visible(line) for line in difflib.unified_diff(_split(before), _split(after), a, b, lineterm="")]


def _diff_lines(now: Optional[str], copy: Optional[str]) -> list:
    """기본 브랜치의 지금 글 → 사본의 차이."""
    return _diff(now, copy, "기본 브랜치", "규칙 사본")


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


# ── 대기 줄(pending.md) ───────────────────────────────────────────────────────

def _pending_team(root, roadmap_rel: str):
    """작업 폴더의 로드맵 머리말이 team 형식이고 상태 브랜치를 쓸 수 있으면 그 Team, 아니면 None. 예외를 던지지 않는다."""
    try:
        text = (Path(str(root)) / roadmap_rel).read_text(encoding="utf-8")
    except (OSError, ValueError):
        return None
    if not roadmap_model.is_team(roadmap_model.frontmatter(text)) or CB.availability(root, roadmap_rel) is not None:
        return None
    try:
        return CB.team_of(root, roadmap_rel)
    except CB.BranchError:
        return None


def pending_team(root, roadmap_rel: str) -> bool:
    """team 형식이고 상태 브랜치가 켜져 있는가 — 브랜치가 아직 없어도 참이다(그때 대기 줄은 기계 상태에 쌓고 알린다)."""
    return _pending_team(root, roadmap_rel) is not None


def pending_on_branch(root, roadmap_rel: str) -> bool:
    """대기 줄의 상태 브랜치 자리 — team 형식 · 쓸 수 있음 · 상태 브랜치 로컬 끝이 있음."""
    team = _pending_team(root, roadmap_rel)
    return team is not None and CB.local_tip(root, team.name) is not None


def _pending_line(row: dict) -> str:
    return "- " + cs.SEP.join(row[c] for c in PENDING_COLUMNS)


def _row_key(row: dict) -> tuple:
    return tuple(row[c] for c in PENDING_COLUMNS)


def _parse_line(raw: str) -> Optional[dict]:
    """`pending.md` 한 줄 → 줄(`{"에픽", "절", "글"}`), 꼴 밖이면 None. 칸은 기계 상태 줄처럼 앞뒤 공백을 벗긴다."""
    line = _bare(raw)
    if not line.startswith("- "):
        return None
    cells = [c.strip() for c in line[2:].split(cs.SEP, len(PENDING_COLUMNS) - 1)]
    if len(cells) != len(PENDING_COLUMNS) or not all(cells):
        return None
    return dict(zip(PENDING_COLUMNS, cells))


def _parse_pending(text: Optional[str]) -> tuple:
    """(줄들, 꼴이 틀린 줄 수) — 빈 줄은 세지 않는다."""
    rows, bad = [], 0
    for raw in _split(text):
        if not _bare(raw).strip():
            continue
        row = _parse_line(raw)
        if row is None:
            bad += 1
        else:
            rows.append(row)
    return rows, bad


def _added_lines(root, commit: str, path: str) -> Optional[list]:
    """커밋 하나가 첫째 부모에 견줘 `path` 에 더한 줄들(날 글 · 다중집합). 그 커밋의 글을 읽지 못하면 None — 남의 고침 판정이
    이 커밋이 그 경로를 바꿨다고 했으니 「더한 줄 없음」 이 아니다(재지 못함으로 닫는다). 첫째 부모를 읽지 못하면 그 커밋의 줄 전부."""
    after = CB.read(root, commit, path)
    if after is None:
        return None
    parent = _first_parent(root, commit)
    gone = collections.Counter(_bare(l) for l in _split(CB.read(root, parent, path) if parent else None))
    added = []
    for raw in _split(after):
        if gone[_bare(raw)] > 0:
            gone[_bare(raw)] -= 1
        else:
            added.append(_bare(raw))
    return added


def pending_rows(root, roadmap_rel: str) -> tuple:
    """(줄들, 확인 안 된 줄들 | None, 확인 안 된 꼴이 틀린 줄 수) — 읽을 끝의 `pending.md`. 확인 안 된 줄은 확인되지 않은 남의 고침
    커밋들이 더한 줄 가운데 지금 남은 것(다중집합)이다. 꼴이 틀린 줄도 같은 커밋들이 더해 지금 남은 것만 센다(확인한 글의 것은 세지 않는다).
    대기 줄 쪽 판정이 None(재지 못함 — 남의 커밋의 글을 읽지 못한 것도)이면 둘째 값이 None 이고 셋째는 0 이다(I11 — 부르는 쪽이
    「남의 고침을 재지 못했다」 로 닫고 pending.md 줄을 옮기지 않는다). 상태 브랜치가 갈라졌거나 없으면 BranchError(1).
    남의 글을 읽지만 예외로 죽지 않는다."""
    team = CB.team_of(root, roadmap_rel)
    seen = _read_tip(root, team.name)
    path = team.path(CB.PENDING_FILE)
    text = CB.read(root, seen, path)
    rows, _bad = _parse_pending(text)
    found = foreign(root, roadmap_rel, seen, TS.pending_paths(team))
    if found is None:
        return rows, None, 0
    left = collections.Counter(_row_key(r) for r in rows)
    odd = collections.Counter(_bare(raw) for raw in _split(text) if _bare(raw).strip() and _parse_line(raw) is None)
    unconfirmed, bad = [], 0
    for commit, _paths in found:
        added = _added_lines(root, commit, path)
        if added is None:
            return rows, None, 0
        for raw in added:
            row = _parse_line(raw)
            if row is not None and left[_row_key(row)] > 0:
                left[_row_key(row)] -= 1
                unconfirmed.append(row)
            elif row is None and odd[raw] > 0:
                odd[raw] -= 1
                bad += 1
    return rows, unconfirmed, bad


def _check_pending_row(row) -> None:
    """대기 줄 하나 — 칸 셋이 비지 않고 앞뒤 공백 · 줄 가름 글자가 없으며, 에픽 · 절에는 칸 구분자가 없다. 아니면 BranchError(2)."""
    cells = [row.get(c) for c in PENDING_COLUMNS] if isinstance(row, dict) else [None]
    for i, cell in enumerate(cells):
        if (not isinstance(cell, str) or not cell or cell.strip() != cell or cell.splitlines() != [cell]
                or (i < len(PENDING_COLUMNS) - 1 and (cs.SEP in cell or cell.startswith("·") or cell.endswith("·")))):
            raise CB.BranchError(2, "대기 줄은 칸 %d개(%s)의 한 줄이다: %s"
                                 % (len(PENDING_COLUMNS), " · ".join(PENDING_COLUMNS), CB.visible(repr(row))))


def pending_add(root, roadmap_rel: str, session: str, row: dict) -> CB.Result:
    """상태 브랜치의 `pending.md` 끝에 `- <에픽> · <절> · <글>` 한 줄을 더한다 — 같은 줄이 있어도 더한다(다중집합).
    표지가 아니면 BranchError(5) · 꼴 밖이면 2 · 상태 브랜치가 갈라졌거나 없으면 1. 쓸 수 없으면 알림만 담은 결과(commit None)."""
    CB._need_marker(root, roadmap_rel, session)
    _check_pending_row(row)
    team = CB.team_of(root, roadmap_rel)
    _seen, moved = _writable_tip(root, roadmap_rel, team)
    path, line = team.path(CB.PENDING_FILE), _pending_line(row)

    def edit(base):
        return {path: "".join(item + "\n" for item in _split(base.read(path)) + [line])}

    res = CB.write(root, roadmap_rel, session, edit, "대기 줄 더함")
    return res._replace(notes=moved + res.notes)


def pending_drop(root, roadmap_rel: str, session: str, rows: list, what: str = "대기 줄 지움") -> CB.Result:
    """상태 브랜치의 `pending.md` 에서 `rows` 를 다중집합으로 뺀다 — 줄마다 칸이 같은 줄을 앞에서부터 하나씩(없으면 지나간다).
    남의 줄도 뺀다(사람 줄을 지우는 길 — S8). 뺄 것이 없으면 커밋하지 않는다(commit None). 오류는 `pending_add` 와 같다."""
    CB._need_marker(root, roadmap_rel, session)
    if not all(isinstance(r, dict) and all(isinstance(r.get(c), str) for c in PENDING_COLUMNS) for r in rows):
        raise CB.BranchError(2, "뺄 대기 줄은 칸 %s 을 가진 줄이다" % " · ".join(PENDING_COLUMNS))   # 남의 줄도 받는다 — 꼴은 읽은 대로
    if not rows:
        return CB.Result(None, False, None, ())
    team = CB.team_of(root, roadmap_rel)
    _seen, moved = _writable_tip(root, roadmap_rel, team)
    path = team.path(CB.PENDING_FILE)
    want = collections.Counter(_row_key(r) for r in rows)

    def edit(base):
        left, keep = want.copy(), []
        lines = _split(base.read(path))
        for raw in lines:
            row = _parse_line(raw)
            if row is not None and left[_row_key(row)] > 0:
                left[_row_key(row)] -= 1
            else:
                keep.append(raw)
        if len(keep) == len(lines):
            return None
        return {path: "".join(item + "\n" for item in keep)}

    res = CB.write(root, roadmap_rel, session, edit, what)
    return res._replace(notes=moved + res.notes)


# ── 남의 고침 확인 · 기준 끝 옮기기 ────────────────────────────────────────────

def _watched(team) -> list:
    """남의 고침을 재는 두 쪽 경로 — 규칙 사본 · rules-base.md · pending.md."""
    return TS.rules_paths(team) + TS.pending_paths(team)


def _trust_rows(root, roadmap_rel: str) -> list:
    """기계 상태 `확인한 끝` 절의 줄들. 읽지 못하면 BranchError(3) — 남의 고침을 재지 못했다."""
    try:
        return cs.load(cs.machine_path(state_path.state_root(str(root)), roadmap_rel), roadmap_rel)[cs.TRUST]
    except Exception as exc:
        raise CB.BranchError(3, "%s — 기계 상태를 읽지 못했다 — %s: %s" % (FOREIGN_UNMEASURED, type(exc).__name__, CB.visible(CB._first_line(exc))))


def _first_parent(root, commit: str) -> Optional[str]:
    rc, out, _e = CB.git(root, "rev-parse", "--verify", "-q", commit + "^1")
    out = out.strip()
    return out if rc == 0 and CB.OID_RE.fullmatch(out) else None


def _commit_lines(root, commit: str, paths, watched: list, parents: int = 1) -> list:
    """커밋 하나의 보고 — `<8자> · <때> · [머지 커밋 · 부모 n · ]<경로들>` 과 지켜보는 경로마다 첫째 부모와의 차이(줄마다 `│ `)."""
    parent = _first_parent(root, commit)
    head = [commit[:8], CB._commit_stamp(root, commit)] + ([MERGE_MARK % parents] if parents > 1 else [])
    out = [" · ".join(head + [", ".join(CB.visible(p) for p in paths) or "-"])]
    for path in paths:
        if path in watched:
            out += _diff(CB.read(root, parent, path) if parent else None, CB.read(root, commit, path),
                         path + " (첫째 부모)", path + " (이 커밋)")
    return out


def _foreign_report(root, team, tip: str, rows: list) -> tuple:
    """(보고 줄들, 확인이 필요한가). 판정이 None 이면 확인 끝 없이 다시 세고, 그래도 None 이면 범위의 `씀` 밖 커밋 전부를 보인다 —
    판정이 None 이었으면 보일 커밋이 없어도 확인이 필요하다(재지 못함을 빠져나가는 길이 confirm 이다)."""
    git, watched = Git(str(root)), _watched(team)
    trust = TS.trust_of(rows)
    found = TS.foreign_commits(git, tip, trust, watched)
    lead = ""
    if found is None:
        own = frozenset(r["끝"] for r in rows if r["까닭"] == cs.TRUST_WHY[1])
        found = TS.foreign_commits(git, tip, (None, own), watched)
        lead = FOREIGN_UNMEASURED + RECOUNTED
        if found is None:
            return _unwritten_report(root, git, watched, tip, trust, own), True
    if not found and not lead:
        return [], False
    lines = [lead + FOREIGN % len(found) + CONFIRM_HOW]
    for commit, paths in found:
        lines += _commit_lines(root, commit, paths, watched)
    return lines, True


def _unwritten_report(root, git, watched: list, tip: str, trust, own) -> list:
    """`<확인 끝>..<tip>`(확인 끝이 없거나 이 레포에 없으면 tip 의 이력 전부)에서 `씀` 에 없는 커밋 전부 — 오래된 차례."""
    base = trust[0] if trust else None
    if base is not None and git.commit(base) is None:
        base = None
    rc, out, err = git.run_err("log", "--format=%H %P", "%s..%s" % (base, tip) if base else tip)
    if rc != 0:
        raise CB._git_fail(err, FOREIGN_UNMEASURED + " — 커밋을 읽지 못했다")
    picked = []
    for line in out.splitlines():
        words = line.split()
        if not words or not all(CB.OID_RE.fullmatch(w) for w in words):
            raise CB.BranchError(3, FOREIGN_UNMEASURED + " — 커밋 줄을 읽지 못했다")
        if words[0] not in own:
            picked.append((words[0], len(words) - 1))
    lines = [FOREIGN_UNMEASURED + UNWRITTEN % len(picked) + CONFIRM_HOW]
    for commit, parents in reversed(picked):
        paths = [path for _s, path in CB._changed(root, _first_parent(root, commit), commit)]
        lines += _commit_lines(root, commit, paths, watched, parents)
    return lines


def confirm(root, roadmap_rel: str, session: str, confirmed: Optional[str] = None) -> tuple:
    """(확인한 끝, 알림들). `confirmed` 가 없으면 읽을 끝까지의 확인되지 않은 남의 고침(규칙 · 대기 줄 두 쪽)을 커밋마다 차이와 함께
    보이고 마지막 줄 `확인할 끝: <40자>` 로 BranchError(1) — 남의 고침이 없으면 (끝, (NOTHING_TO_CONFIRM,)).
    `confirmed` 는 40자 전체만 받고(아니면 BranchError(2)) 지금 읽을 끝과 같을 때만 `확인한 끝` 을 `확인 · <그 끝>` 한 줄로 둔다 —
    다르면 다시 센 보고로 BranchError(1). 기계 상태를 읽지 못하거나 상태 브랜치가 갈라졌으면 BranchError(3), 없으면 1.
    쓸 수 없는 레포(꺼짐 · 규칙 거절 · 설정 오류)면 (None, (알림,)) — 표지는 그보다 먼저 본다."""
    CB._need_marker(root, roadmap_rel, session)
    why = CB.availability(root, roadmap_rel)   # 표지(5) → 쓸 수 있는지(설정 오류면 알리고 0) → 값 차례다(M25 ②)
    if why:
        return None, (why,)
    if confirmed is not None and (not isinstance(confirmed, str) or not CB.OID_RE.fullmatch(confirmed)):
        raise CB.BranchError(2, "--confirmed 는 확인할 끝 40자 전체를 받는다(앞 8자는 받지 않는다)")
    team = CB.team_of(root, roadmap_rel)
    rows = _trust_rows(root, roadmap_rel)
    seen, split = CB.seen_tip(root, team.name)
    if seen is None:
        if split:
            raise CB.BranchError(3, "%s — %s" % (FOREIGN_UNMEASURED, CB.visible(split)))
        raise CB.BranchError(1, NO_STATE_BRANCH)
    if confirmed == seen:
        try:
            told = confirm_at(root, roadmap_rel, session, seen)
        except Exception as exc:
            raise CB.BranchError(3, "확인한 끝을 기록하지 못했다 — %s: %s" % (type(exc).__name__, CB.visible(CB._first_line(exc))))
        return seen, told + (CONFIRMED % seen,)
    lines, needed = _foreign_report(root, team, seen, rows)
    if not needed:
        return seen, (NOTHING_TO_CONFIRM,)
    lead = [NOT_THE_TIP] if confirmed is not None else []
    raise CB.BranchError(1, "\n".join(lead + lines + [CONFIRM_TIP % seen]))


def settle(root, roadmap_rel: str, session: str, tip: str, notes: Optional[list] = None) -> Optional[int]:
    """`tip`(쓴 뒤 읽을 끝)에서 두 쪽의 확인되지 않은 남의 고침 수(규칙 · 대기 줄 경로를 바꾼 서로 다른 커밋)를 세고 `확인한 끝` 절을 줄인다.
    0 이면 절을 `확인 · <tip>` 한 줄로, 아니면 `씀` 줄 가운데 `<확인 끝>..<tip>` 에 없는 것(다시 만들기로 버려진 커밋)만 지운다.
    재지 못하면 None — 절을 건드리지 않는다. `notes` 를 주면 알릴 줄을 더한다(옛 `## 레포 설정` 절을 지움 · 「씀」 줄이 500 을 넘음)."""
    team = CB.team_of(root, roadmap_rel)
    path = cs.machine_path(state_path.state_root(str(root)), roadmap_rel)
    try:
        data = cs.load(path, roadmap_rel)
    except Exception:
        return None
    rows = data[cs.TRUST]
    trust = TS.trust_of(rows)
    git = Git(str(root))
    found = TS.foreign_commits(git, tip, trust, _watched(team))
    if found is None:
        return None
    keep = rows
    if not found:
        if [(r["끝"], r["까닭"]) for r in rows] != [(tip, cs.TRUST_WHY[0])]:
            keep = [{"끝": tip, "까닭": cs.TRUST_WHY[0], "때": CB.stamp(), "세션": session}]
    else:
        rc, out, _e = git.run_err("log", "--format=%H", "%s..%s" % (trust[0], tip) if trust[0] else tip)
        if rc == 0:
            inside = set(out.split())
            keep = [r for r in rows if r["까닭"] == cs.TRUST_WHY[0] or r["끝"] in inside]
    if keep != rows:
        old_settings = cs.has_old_repo_settings(path)
        data[cs.TRUST] = keep
        cs.save(path, roadmap_rel, data, session)
        if old_settings and notes is not None:
            notes.append(cs.OLD_REPO_SETTINGS_DROPPED)
    if notes is not None and len([r for r in keep if r["까닭"] == cs.TRUST_WHY[1]]) > OWN_ROWS_MAX:
        notes.append(LONG_FOREIGN)
    return len(found)
