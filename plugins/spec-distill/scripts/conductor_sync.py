#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_sync.py — 지휘 걸음 1(맞추기)의 정해진 차례를 명령 하나로 돈다.

차례: 자리 → 원격 받기 → 작업 목록 → 표지 → 기본 브랜치 → PR 캐시 → 상태 브랜치 → 세션 담당자 → 스위트 잠금 → 실행 원장
→ (표지를 새로 잡았거나 넘겨받았을 때만) 주인 모를 worktree · 판 차이 → 차례 표 읽기 → 끝 묶음.
구간마다 한 줄을 내고, 이상이 있는 구간만 그 원문을 네 칸 들여 낸다. 구간이 멈출 사유를 내면 `멈춤 — <구간>: <사유>` 와
원문을 내고 그 종료 코드로 끝난다(뒤 구간은 돌지 않는다). 끝 묶음은 규모 줄 · (team 형식이면) 리더 묶음 명령 한 줄 ·
끝나지 않은 일마다 서 있는 걸음과 지시서 · 머지 뒤 일이 남은 에픽 · 병렬 판단 줄 · 시각 줄이다. PR 캐시 구간이 캐시를
고쳤으면 끝 묶음은 작업 목록을 고친 캐시로 다시 센다(작업 목록 구간 줄은 처음 계산 그대로).

기계 상태 · 상태 브랜치는 직접 쓰지 않는다 — 쓰는 일은 부르는 스크립트(원장 · 상태 브랜치 · 현황)가 한다.
표의 줄을 지우거나 터미널을 닫지 않는다 — 어긋난 줄을 낼 뿐이다.

명령줄: conductor_sync.py --roadmap <로드맵> [--session <세션>] [--takeover]
종료 코드: 0 · 멈춤이면 그 구간의 종료 코드(세션 번호 없음 3 · 다른 세션이 쥠 5 · 기계 상태 읽기 불가 3 …) · 2 사용법.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime
import io
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SD = HERE.parent
sys.path.insert(0, str(HERE))
import conductor_branch as CB  # noqa: E402
import conductor_ledger as L  # noqa: E402
import conductor_state as cs  # noqa: E402
import conductor_status as CS  # noqa: E402
import conductor_toc as TOC  # noqa: E402
import control_plane as CP  # noqa: E402
import roadmap_status as RS  # noqa: E402
import team_layout as TL  # noqa: E402

INDENT = "    "
PREFIX = "[spec-distill] "
STAMP = "%Y-%m-%d %H:%M"
AGENTS = "살아 있는 agent"
HC_FINISHED = "finished"   # `hc ls --all` 이 함께 내는 끝난 터미널의 state — 살아 있는 내 자식으로 세지 않는다
LEFT_ROWS = ("작업", "자원", AGENTS)   # 머지 뒤 일이 남았는지 보는 기계 상태 절(에픽 칸이 그 에픽인 줄) — 걸음 6 이 치우는 줄만 센다
LEFT_KIND = "worktree"   # 자원 가운데 걸음 6 이 치우는 종류 — 보관 · 임시 · 옮김 폴더 같은 자원 줄은 세지 않는다(설계 §2)
AGENTS_PER_EPIC = 9   # 계획 1 · 구현 1 · 통합 리뷰 1 · qg 담당자 4 · spec 리뷰 한 라운드의 리뷰어 2
AGENTS_ROADMAP_END = 1   # 로드맵 끝 qg 담당자
SCALE_TAIL = ("spec 리뷰는 라운드마다 리뷰어 agent 둘 이상, 엔진의 재리뷰 상한까지(사용자가 더 열 수 있다) · "
              "구현 안 agent 수는 task 수에 따라 — 상한 없음")
NO_STEP = "걸음 없음 — 차례 표에 이 단계가 없다"
TASKS_RC4 = "로드맵이 아직 기본 브랜치에 없다 — 손 절차 1 의 대신 계산을 쓴다"
CLAIM_NEW, CLAIM_HELD = "acquired", "held"   # `ledger claim` 이 rc 0 으로 내는 두 낱말
TAKEN_FROM = "이전 주인: "
PR_SUMMARY = "PR 캐시: "   # `ledger pr-refresh` 가 끝에 내는 한 줄의 머리
PROGRESS_STAMP = re.compile(r" · 마지막 고침 ([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2})\(")
ENSURE_OK = ("만들었다 — ", "있다 — ")
TOUCH_HEAD = "다른 로드맵과 닿는 것 (계산 "
TOUCH_NONE = "- 닿는 것 없음"
TOUCH_INFO = ("- 예약 겹침: ", "- 바꾼 파일 겹침: ", "- 기본 브랜치의 움직임: ", "- 이 기계에서 도는 스위트: ")
WAITING_HEAD = "사용자를 기다리는 질문 (오래된 순)"
QUIET_TAIL = " · 기다리는 질문 없음   (STATUS "
LETTERS_RE = re.compile(r"온 글 ([0-9]+) · 아직 받지 않은 보낸 글 ([0-9]+) · 답 기다리는 글 ([0-9]+)")
MAIL_RE = re.compile(r"보낸 글 [0-9]+ · 아직 받지 않은 보낸 글 ([0-9]+) · 답 기다리는 글 ([0-9]+) · 받은 글 [0-9]+")   # STATUS 의 편지 절
RULES_ZERO = "0줄"
MAIL = "편지"
NEEDED = ("STATUS", "다른 로드맵과 닿는 것", "사용자를 기다리는 질문", "온 글")   # 이상 없음 꼴의 현황 화면에 있어야 할 줄


class Stop(Exception):
    def __init__(self, segment, reason, rc, raw=()):
        super().__init__(reason)
        self.segment, self.reason, self.rc, self.raw = segment, reason, rc, list(raw)


def say(line=""):
    print(line, flush=True)


def indented(lines):
    for ln in lines:
        say(INDENT + ln if ln else "")


def segment(name, text):
    say("%s — %s" % (name, text))


def anomaly(name, text, raw):
    segment(name, "이상: " + text)
    indented(raw)


def run(argv):
    """(rc, 표준 출력 줄들, 표준 오류 줄들) — 부른 곳을 작업 폴더로."""
    try:
        p = subprocess.run(argv, capture_output=True, encoding="utf-8", errors="replace")
    except OSError as exc:
        return 127, [], ["실행하지 못했다 — %s" % exc]
    return p.returncode, p.stdout.splitlines(), p.stderr.splitlines()


def script(name, *args):
    return run([sys.executable, str(HERE / name), *args])


def reason_of(lines, rc):
    """멈춘 사유 한 줄 — 스크립트의 알림 줄(`[spec-distill] …`)이 있으면 그 첫 줄, 없으면 첫 글 줄."""
    said = [ln.strip()[len(PREFIX):] for ln in lines if ln.strip().startswith(PREFIX)]
    plain = [ln.strip() for ln in lines if ln.strip()]
    return (said or plain or ["종료 코드 %d" % rc])[0]


def sd_command(name, *args):
    return 'python3 "%s"/scripts/%s %s' % (SD, name, " ".join(args))


# ── 구간 ─────────────────────────────────────────────────────────────────────

def seg_place():
    rc1, top, e1 = run(["git", "rev-parse", "--show-toplevel"])
    rc2, wl, e2 = run(["git", "worktree", "list", "--porcelain"])
    if rc1 or rc2 or not top or not wl:
        anomaly("자리", "어디인지 읽지 못했다", top + e1 + wl + e2)
        return os.getcwd()
    main = wl[0][len("worktree "):] if wl[0].startswith("worktree ") else wl[0]
    if os.path.realpath(top[0]) == os.path.realpath(main):
        segment("자리", "메인 체크아웃")
    else:
        segment("자리", "worktree 안에서 시작했다(%s) — 여기서도 지휘한다" % top[0])
    return top[0]


def seg_fetch():
    rc, out, err = run(["git", "fetch", "origin"])
    if rc:
        anomaly("원격 받기", "받지 못했다(종료 코드 %d)" % rc, out + err)
    else:
        segment("원격 받기", "됨")


def task_view(roadmap):
    """(보고 | None, 작업 목록 줄들, 표준 오류 글, rc) — `control_plane.py show --tasks` 와 같은 계산."""
    off = CP.switch_name()
    if off:
        return None, [], "꺼져 있다 — %s" % off, 3
    try:
        v = CP.gather(os.getcwd(), roadmap, CP.Deadline(CP.SHOW_BUDGET), {})
    except CP.TimedOut as exc:
        return None, [], CP.clean("검사 불가 — 시간 초과(%s, %d초)" % (exc, CP.SHOW_BUDGET)), 3
    except Exception as exc:  # noqa: BLE001 — 계산이 죽어도 맞추기는 끝까지 간다
        return None, [], CP.clean("검사 불가 — 내부 오류(%s: %s)" % (type(exc).__name__, exc)), 3
    shown = v["select_error"] or (v.get("no_default") if not v["items"] else None)
    out, err, rc = CP.tasks_output(v["items"], shown)
    return (v["items"][0][1] if rc == 0 else None), out, err, rc


def work_items(report, lines):
    """[(작업 목록의 제목, 걸음을 고를 단계, 끝인가, 블록 | None)] — tasks_output 이 탭 있는 줄을 낸 차례(블록 · 과제 · 로드맵
    밖 줄) 그대로. 일부 머지 블록은 지금 브랜치의 단계로 걸음을 고르고, 지금 브랜치가 없을 때만 「일부 머지」 그대로다."""
    blocks = report.get("blocks") or []
    jobs = report.get("jobs") or []
    outside = [w for w in (report.get("machine") or {}).get("작업") or [] if w["에픽"] == CP.OUTSIDE]
    sources = ([(CP.active_stage(b) or b.get("stage"), b.get("stage") in RS.DONE, b) for b in blocks]
               + [(j.get("stage"), j.get("stage") in RS.DONE, None) for j in jobs]
               + [(w["단계"], w["단계"] in cs.WORK_DONE, None) for w in outside])
    titles = [ln.split("\t", 1)[0] for ln in lines if "\t" in ln]
    if len(titles) != len(sources):
        return None
    return [(t, stage, done, b) for t, (stage, done, b) in zip(titles, sources)]


def tasks_of(roadmap):
    """(보고 | None, 작업 목록 줄들, 일들 | None, 표준 오류 글, rc)."""
    report, lines, err, rc = task_view(roadmap)
    return report, lines, (work_items(report, lines) if report is not None else None), err, rc


def seg_tasks(roadmap):
    report, lines, items, err, rc = tasks_of(roadmap)
    if rc == 0 and report is not None and items is not None:
        segment("작업 목록", "에픽 %d · 끝나지 않은 일 %d" % (len(report.get("blocks") or []),
                                                     sum(1 for it in items if not it[2])))
    elif rc == 0:
        anomaly("작업 목록", "작업 목록 줄을 일과 맞추지 못했다", lines)
    else:
        anomaly("작업 목록", TASKS_RC4 if rc == 4 else "검사 불가(종료 코드 %d)" % rc, lines + err.splitlines())
    return report, lines, items


def seg_marker(roadmap, given, takeover):
    """(세션, 처음인가)."""
    try:
        with contextlib.redirect_stderr(io.StringIO()):   # 해결자의 영어 한 줄은 이 명령의 꼴이 아니다
            sid = L.session_or_fail(given)
    except L.Fail as exc:
        raise Stop("표지", str(exc), exc.rc)
    rc, out, err = script("conductor_ledger.py", "takeover" if takeover else "claim", "--roadmap", roadmap, "--session", sid)
    if rc:
        raise Stop("표지", reason_of(out + err, rc), rc, out + err)
    last = out[-1].strip() if out else ""
    if takeover:
        prev = last.rpartition(TAKEN_FROM)[2] if TAKEN_FROM in last else last
        verdict, first = "넘겨받았다(이전 주인 %s)" % prev, True
    elif last == CLAIM_NEW:
        verdict, first = "새로 잡았다", True
    elif last == CLAIM_HELD:
        verdict, first = "이 세션이 쥐고 있다", False
    else:
        anomaly("표지", "원장이 모르는 낱말을 냈다", out + err)
        return sid, False
    if out[:-1] or err:   # 원장의 알림(옛 레포 설정 줄을 지웠다 · 상태 루트 알림 …)은 한 번만 나온다 — 삼키지 않는다
        anomaly("표지", verdict + " · 알림이 있다", out + err)
    else:
        segment("표지", verdict)
    return sid, first


def seg_default(roadmap, sid):
    rc, out, err = script("repo_defaults.py", "default-branch", "--check-remote")
    if rc:
        _rc, rout, rerr = script("conductor_ledger.py", "release", "--roadmap", roadmap, "--session", sid)
        raise Stop("기본 브랜치", reason_of(err + out, rc), rc, out + err + rout + rerr)
    name = out[-1].strip() if out else ""
    if err:
        anomaly("기본 브랜치", "%s — 원격과 대조하지 못했다" % name, out + err)
    else:
        segment("기본 브랜치", name)


def pr_rows(root, roadmap):
    """{(브랜치, 번호): 상태} — 「PR 0개」 줄은 빼고. 읽지 못하면 사유 글."""
    try:
        rows = L.load(root, roadmap)["PR"]
    except Exception as exc:  # noqa: BLE001 — 견주지 못한 것으로 낸다
        return str(exc)
    return {(r["브랜치"], r["번호"]): r["상태"] for r in rows if r["번호"] != cs.NO_PR}


def seg_pr(root, roadmap, sid):
    """캐시가 바뀌었는가 — 단계 계산이 캐시를 읽으므로 바뀌었으면 끝 묶음은 작업 목록을 다시 센다."""
    before = pr_rows(root, roadmap)
    rc, out, err = script("conductor_ledger.py", "pr-refresh", "--roadmap", roadmap, "--session", sid)
    if rc == 3:
        raise Stop("PR 캐시", reason_of(out + err, rc), rc, out + err)
    after = pr_rows(root, roadmap)
    raw = out + err
    odd = rc != 0 or err or any(not ln.startswith(PR_SUMMARY) for ln in out)
    if isinstance(before, str) or isinstance(after, str):
        anomaly("PR 캐시", "캐시를 견주지 못했다 — %s" % (before if isinstance(before, str) else after), raw)
        return True
    changed = ["%s %s %s → %s" % (br, no, before.get((br, no), "없음"), after.get((br, no), "없음"))
               for br, no in sorted(set(before) | set(after)) if before.get((br, no)) != after.get((br, no))]
    if changed:
        anomaly("PR 캐시", "고쳤다 — " + " · ".join(changed), raw)
    elif odd:
        anomaly("PR 캐시", "알림이 있다(종료 코드 %d)" % rc, raw)
    else:
        segment("PR 캐시", "달라진 것 없음")
    return bool(changed)


def _status_block(lines):
    """show 출력 머리의 STATUS 글 — (끝 자리, 이상 줄들). STATUS 가 아니면 그 머리 줄을 이상으로."""
    if not lines or not lines[0].startswith(CS.TITLE_HEAD):
        return 1, [ln for ln in lines[:1] if ln]
    last = "## " + CS.STATUS_SECTIONS[-1]
    end = next((i for i, ln in enumerate(lines) if ln == last), None)
    if end is not None:
        end = next((i for i in range(end + 1, len(lines)) if not lines[i].startswith("- ")), len(lines))
    try:
        status = CS.parse_status("\n".join(lines[:end]) + "\n") if end is not None else None
    except CS.StatusError:
        status = None
    if status is None:
        stop = next((i for i, ln in enumerate(lines) if ln.startswith(TOUCH_HEAD)), len(lines))
        return stop, [ln for ln in lines[:stop] if ln]
    odd = ["- " + q for q in status.sections["기다리는 질문"] if q != CS.NONE_LINE]
    odd += ["## %s: %s" % (MAIL, r) for r in status.sections[MAIL]
            if not (MAIL_RE.fullmatch(r) and MAIL_RE.fullmatch(r).groups() == ("0", "0"))]
    odd += ["## %s: %s" % (CS.STATUS_SECTIONS[-1], r) for r in status.sections[CS.STATUS_SECTIONS[-1]] if r != RULES_ZERO]
    return end, odd


def read_view(lines, info=None):
    """(기다리는 질문 수, 온 글 수, 닿는 것 수, 이상 줄들, 빠진 줄들) — 아는 「이상 없음」 꼴이 아닌 줄은 모두 이상이고,
    이상 없음 꼴에 있어야 할 줄(`NEEDED`)이 빠져도 이상이다. `info` 를 주면 정보 줄(닿는 것)의 자리를 거기에 담는다."""
    end, odd = _status_block(lines)
    waiting = letters = touch = 0
    part = "head"
    seen = {NEEDED[0]} if lines and lines[0].startswith(CS.TITLE_HEAD) else set()
    for i, ln in enumerate(lines[end:], end):
        if ln.startswith(TOUCH_HEAD):
            part = "touch"
            seen.add(NEEDED[1])
            continue
        if ln == WAITING_HEAD:
            part = "waiting"
            seen.add(NEEDED[2])
            continue
        m = LETTERS_RE.fullmatch(ln)
        if m:
            part = "letters"
            seen.add(NEEDED[3])
            letters = int(m.group(1))
            if m.groups() != ("0", "0", "0"):
                odd.append(ln)
            continue
        if part == "head" and ln == "":
            continue
        if part == "touch" and ln == TOUCH_NONE:
            continue
        if part == "touch" and ln.startswith(TOUCH_INFO):
            touch += 1
            if info is not None:
                info.append(i)
            continue
        if part == "waiting" and (ln == "- " + CS.NONE_LINE or QUIET_TAIL in ln or ln.endswith(" · " + CB.NO_BRANCH)):
            continue
        if part == "waiting" and ln.startswith("- ") and "부터" in ln:
            waiting += 1
        odd.append(ln)
    return waiting, letters, touch, odd, [n for n in NEEDED if n not in seen]


def _off_view(outs, show):
    """상태 브랜치를 꺼 둔 레포의 꼴인가 — ensure · sync 가 `[spec-distill] <꺼져 있다>` 한 줄씩이고 show 의 첫 줄이 그 글이면
    (닿는 것 수, 이상 줄들, 빠진 줄들, 정보 줄 자리)를 show 의 나머지(닿는 것 절)에서 읽고, 아니면 None."""
    if any(o != [PREFIX + CB.OFF_NOTE] for o in outs) or not show or show[0] != CB.OFF_NOTE:
        return None
    info = []
    _w, _l, touch, odd, missing = read_view(show[1:], info)
    return touch, odd, [m for m in missing if m == NEEDED[1]], [i + 1 for i in info]


def seg_state_branch(roadmap, sid):
    odd, raw, outs = [], [], []
    for args, ok in ((("conductor_branch.py", "ensure", "--roadmap", roadmap, "--session", sid), ENSURE_OK),
                     (("conductor_status.py", "sync", "--roadmap", roadmap, "--session", sid), (CS.UNCHANGED,))):
        rc, out, err = script(*args)
        if rc in (3, 5):
            raise Stop("상태 브랜치", reason_of(err + out, rc), rc, raw + out + err)
        raw += out + err
        outs.append(out + err + (["종료 코드 %d" % rc] if rc else []))
        if rc:
            odd.append("%s %s 종료 코드 %d" % (args[0], args[1], rc))
        odd += [ln for ln in out + err if not (ln.startswith(PREFIX) and ln[len(PREFIX):].startswith(ok))]
    rc, out, err = script("conductor_status.py", "show", "--roadmap", roadmap)
    if rc in (3, 5):
        raise Stop("상태 브랜치", reason_of(err + out, rc), rc, raw + out + err)
    off = None if rc or err else _off_view(outs, out)
    info = []
    if off is not None:   # 꺼 둔 레포 — 세 명령의 꺼짐 줄은 아는 꼴이고, 있어야 할 줄은 닿는 것 절 하나다
        touch, odd, missing, info = off
        head, notes = "꺼져 있다", []
    else:
        waiting, letters, touch, seen, missing = read_view(out, info)
        odd += seen + err + (["conductor_status.py show 종료 코드 %d" % rc] if rc else [])
        head = "기다리는 질문 %d · 온 글 %d" % (waiting, letters)
        notes = [ln for ln in odd if ln.startswith("conductor_")]
    notes += ["빠진 줄: " + " · ".join(missing)] if missing else []
    if odd or missing:   # 원문은 이 구간이 부른 세 명령의 출력 — 정보 줄(닿는 것)만 빼고, 그 수는 아래 한 줄이 낸다
        skip = set(info)
        anomaly("상태 브랜치", " · ".join([head] + notes), raw + [ln for i, ln in enumerate(out) if i not in skip] + err)
    else:
        segment("상태 브랜치", head)
    say("다른 로드맵과 닿는 것 %d개 — 다시 보기: %s" % (touch, sd_command("conductor_status.py", "show", "--roadmap", roadmap)))


def machine_of(root, roadmap):
    try:
        return L.load(root, roadmap), None
    except Exception as exc:  # noqa: BLE001 — 읽지 못한 사유로 낸다
        return None, str(exc)


def seg_workers(machine, why):
    if machine is None:
        anomaly("세션 담당자", "기계 상태를 읽지 못했다", [why])
        return
    rows = machine[AGENTS]
    me = os.environ.get("HC_TERMINAL_ID")
    if not (shutil.which("hc") and me):
        segment("세션 담당자", "hc 없음 — 표의 줄 %d 은 하니스 agent 목록과 견줄 줄" % len(rows))
        return
    rc, out, err = run(["hc", "ls", "--json", "--all"])
    try:
        terms = json.loads("\n".join(out))["terminals"] if rc == 0 else None
        kids = [t for t in terms if t.get("parent") == me and t.get("state") != HC_FINISHED]
    except (ValueError, KeyError, TypeError, AttributeError):
        kids = None
    if kids is None:
        anomaly("세션 담당자", "hc ls 를 읽지 못했다(종료 코드 %d)" % rc, out + err)
        return
    names = {t.get("name") for t in kids}
    table = {r["이름"] for r in rows}
    odd = ["견줄 줄: %s · %s · %s" % (r["이름"], r["에픽"], r["일"]) for r in rows if r["이름"] not in names]
    odd += ["표에 없는 내 자식: %s %s %s" % (t.get("address"), t.get("name") or "(이름 없음)", t.get("status") or t.get("state"))
            for t in kids if t.get("name") not in table]
    head = "표 %d · 내 자식 %d · 어긋남 %d" % (len(rows), len(kids), len(odd))
    if odd:
        anomaly("세션 담당자", head, odd)
    else:
        segment("세션 담당자", head)


def seg_suite(roadmap):
    rc, out, err = script("conductor_ledger.py", "suite-lock", "--roadmap", roadmap)
    if rc or len(out) < 2:
        anomaly("스위트 잠금", "읽지 못했다(종료 코드 %d)" % rc, out + err)
    else:
        segment("스위트 잠금", out[1])


def seg_progress(roadmap):
    rc, out, err = script("conductor_ledger.py", "progress", "--roadmap", roadmap)
    rows = out[1:]
    stamps = [m.group(1) for m in (PROGRESS_STAMP.search(ln) for ln in rows) if m]
    again = sd_command("conductor_ledger.py", "progress", "--roadmap", roadmap)
    if rc or err or len(stamps) != len([r for r in rows if r != "실행 원장 없음"]):
        anomaly("실행 원장", "읽지 못한 원장이 있다(종료 코드 %d) — 다시 보기: %s" % (rc, again), out + err)
    elif not stamps:
        segment("실행 원장", "없음")
    else:
        segment("실행 원장", "%d개 · 가장 늦은 고침 %s — 다시 보기: %s" % (len(stamps), max(stamps), again))


def seg_orphans(roadmap):
    rc, out, err = script("conductor_ledger.py", "orphans", "--roadmap", roadmap)
    if rc or err or len(out) != 1 or "\t" in out[0]:
        anomaly("주인 모를 worktree", "있다(%d)" % sum(1 for ln in out if "\t" in ln), out + err)
    else:
        segment("주인 모를 worktree", "없음")


def seg_version():
    rc, out, err = script("conductor_ledger.py", "version", "--plugin-json", str(SD / ".claude-plugin" / "plugin.json"))
    if rc or err:
        anomaly("판 차이", "있다", out + err)
    else:
        segment("판 차이", "없음")


def seg_toc():
    try:
        return TOC.load(SD)
    except TOC.TocError as exc:
        why = str(exc)
    except Exception as exc:  # noqa: BLE001 — 표를 못 읽어도 맞추기는 끝까지 간다
        why = "%s: %s" % (type(exc).__name__, exc)
    segment("차례", "이상: 표를 읽지 못했다 — %s" % why)
    return None


# ── 끝 묶음 ──────────────────────────────────────────────────────────────────

def order_of(blocks):
    """남은 에픽을 의존 차례로 — 같은 자리는 로드맵 차례."""
    left = [b.get("id") for b in blocks]
    deps = {b.get("id"): [d for d in b.get("deps") or [] if d in left] for b in blocks}
    out = []
    while left:
        ready = [e for e in left if all(d in out for d in deps[e])] or left[:1]
        out.append(ready[0])
        left.remove(ready[0])
    return out


def scale_line(report):
    if report is None:
        return "셀 수 없음 — 작업 목록을 읽지 못했다"
    left = [b for b in report.get("blocks") or [] if b.get("stage") not in RS.DONE]
    ids = [b.get("id") for b in left]
    return "남은 에픽 %d(%s) · agent 약 %d · 순서 %s · %s" % (
        len(ids), " · ".join(ids), AGENTS_PER_EPIC * len(ids) + AGENTS_ROADMAP_END,
        " → ".join(order_of(left)) or "없음", SCALE_TAIL)


def step_tail(toc, stage):
    if toc is None:
        return ""
    s = TOC.step_for(toc, stage or "")
    if s is None:
        return " → " + NO_STEP
    return " → 걸음 %d %s · %s" % (s.number, s.name, TOC.resolve(SD, s.guide))


def counts(sec, row):
    """걸음 6 이 치우는 줄인가 — 끝나지 않은 작업 줄 · 종류가 worktree 인 자원 줄 · 살아 있는 agent 줄."""
    if sec == "작업":
        return row["단계"] not in cs.WORK_DONE
    if sec == "자원":
        return row["종류"] == LEFT_KIND
    return True


def left_rows(machine, epic):
    return [sum(1 for r in machine[sec] if r["에픽"] == epic and counts(sec, r)) for sec in LEFT_ROWS]


def closing(roadmap, report, lines, items, machine, toc):
    say("규모 — " + scale_line(report))
    if report is not None and report.get("layout") == TL.LAYOUT_TEAM:
        say("리더 묶음 — 이 대화에서 처음이면 돌린다: " + sd_command("start_bundle.py", "--roadmap", roadmap, "--role",
                                                               TL.LEADER_ROLE))
    if items is None:
        say("끝나지 않은 일: 셀 수 없음 — 작업 목록을 읽지 못했다")
    else:
        open_ = [it for it in items if not it[2]]
        say("끝나지 않은 일:" + ("" if open_ else " 없음"))
        for title, stage, _done, _b in open_:
            say("- %s%s" % (title, step_tail(toc, stage)))
        done = [it for it in items if it[2] and it[3] is not None]
        if done and machine is None:
            say("머지 뒤 일이 남은 에픽: 셀 수 없음 — 기계 상태를 읽지 못했다")
        rows = [(it, left_rows(machine, it[3].get("id"))) for it in done] if machine is not None else []
        rows = [(it, n) for it, n in rows if sum(n)]
        if rows:
            say("머지 뒤 일이 남은 에픽:")
            for (title, stage, _d, _b), (a, b, c) in rows:
                say("- %s%s · 남은 줄: 작업 %d · %s 자원 %d · 살아 있는 agent %d" % (title, step_tail(toc, stage), a, LEFT_KIND, b, c))
    for ln in lines:
        if "\t" not in ln and ln.startswith(CP.PARALLEL_LINE_HEAD):
            say(ln)
    say("맞추기 — %s 기준" % datetime.datetime.now().strftime(STAMP))


# ── 명령줄 ───────────────────────────────────────────────────────────────────

def sync(roadmap, given, takeover) -> int:
    root = seg_place()
    seg_fetch()
    report, lines, items = seg_tasks(roadmap)
    sid, first = seg_marker(roadmap, given, takeover)
    seg_default(roadmap, sid)
    if seg_pr(root, roadmap, sid):   # 구간 줄은 처음 계산 그대로 두고, 끝 묶음만 고친 캐시로 센다
        report, lines, items = tasks_of(roadmap)[:3]
    seg_state_branch(roadmap, sid)
    machine, why = machine_of(root, roadmap)
    seg_workers(machine, why)
    seg_suite(roadmap)
    seg_progress(roadmap)
    if first:
        seg_orphans(roadmap)
        seg_version()
    toc = seg_toc()
    closing(roadmap, report, lines, items, machine, toc)
    return 0


def main(argv=None) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(prog="conductor_sync.py", description="지휘 걸음 1 의 맞추기를 한 번에 돈다")
    ap.add_argument("--roadmap", required=True)
    ap.add_argument("--session", default=None)
    ap.add_argument("--takeover", action="store_true")
    a = ap.parse_args(argv)
    if not a.roadmap.strip() or a.roadmap.startswith("-"):
        sys.stderr.write("사용법: 로드맵 경로는 비지 않고 - 로 시작하지 않는다\n")
        return 2
    try:
        return sync(a.roadmap, a.session, a.takeover)
    except Stop as exc:
        say("멈춤 — %s: %s" % (exc.segment, exc.reason))
        indented(exc.raw)
        return exc.rc
    except Exception as exc:  # noqa: BLE001 — 예상 밖 예외는 1 로 새지 않게 3 으로 멈춘다
        say("멈춤 — 내부 오류: %s: %s" % (type(exc).__name__, exc))
        return 3


if __name__ == "__main__":
    sys.exit(main())
