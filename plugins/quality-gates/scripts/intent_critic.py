#!/usr/bin/env python3
"""intent-critic 단계 CLI — 입구 · 설정 · 입력 조립 · 출력 검사 · 거름 · 상한 · 답 기록 · 렌더.

하위 명령은 `intent_critic.py <sub> --help` 가 정본이다. 세션 폴더(`--rd`)의 파일 이름:
  intent-config.txt     config 가 쓴다(answers_dir · max_bytes · other_teams_max_bytes · intent_doc_markers 와 출처)
  intent-evidence.txt · intent-origin.md · intent-roadmap.md · intent-intent.md ·
  intent-doubts.md · intent-answered.md · intent-plan.txt     prepare 가 쓴다
  intent-scope.md       prepare 가 쓴다 — 리뷰어의 <scope> 칸(넓이 · 읽은 인용을 받는지 · 바뀐 파일 · 커밋 제목)
  other-teams.md        prepare 가 쓴다 — 다른 팀 기록(other_teams.py). 기록이 없으면 지운다
  intent-prepare-notices.txt  prepare 의 공시 줄(한 줄에 하나) — render 가 결과 절 앞에 싣는다
  intent-slot-<k>-<칸>.md  slots 가 쓴다 — 호출 k(1 첫째 · 2 둘째 · 한 번에 넣은 호출)의 칸 사본(원본 + 끝 줄
                        `qg-slot-end: <값>`). 원본은 그대로다
  intent-critic-1.txt · intent-critic-2.txt                   리뷰어 응답(오케스트레이터가 쓴다)
  intent-questions.yaml  filter 가 쓰고 record 가 고친다
  intent-return.md       gate(건너뜀) · render 가 쓴다
  intent-rendered.txt    render 가 쓴다 — 두 번째 render 는 덧붙이지 않는다
  result.md              render 가 끝에 `## intent-critic` 을 덧붙인다

intent-critic 출력은 판정 밖이다 — findings.yaml · 판정 인자 줄 · PR 코멘트에 쓰지 않는다.
버린 · 거른 후보는 `adjudication.Ledger` 로 센다(filter).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
from typing import List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import yaml  # noqa: E402

from adjudication import Ledger  # noqa: E402
import doc_paths  # noqa: E402
from render_disposition import disposition_report  # noqa: E402
import intent_answers as ia  # noqa: E402
import intent_origin as io_  # noqa: E402
import other_teams as ot  # noqa: E402
import qg_nonce  # noqa: E402

KILL_ENV = "DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC"
DIR_ENV = "DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR"
MAX_ENV = "DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES"
DEFAULT_DIR = "docs/qg-intent-answers"
DEFAULT_MAX = 120000
OTHER_MAX_ENV = "DEVBREW_QUALITY_GATES_OTHER_TEAMS_MAX_BYTES"
MARKERS_ENV = "DEVBREW_QUALITY_GATES_INTENT_DOC_MARKERS"
DEFAULT_OTHER_MAX = 80000
SETTINGS_FILES = (".claude/settings.json", ".claude/settings.local.json")

CONFIG = "intent-config.txt"
EVIDENCE = "intent-evidence.txt"
ORIGIN = "intent-origin.md"
ROADMAP = "intent-roadmap.md"
INTENT = "intent-intent.md"
DOUBTS = "intent-doubts.md"
ANSWERED = "intent-answered.md"
HANDED = "intent-handed.yaml"
HANDED_UNREAD = "넘겨받은 답을 읽지 못함 — "
PLAN = "intent-plan.txt"
PREPARE_NOTICES = "intent-prepare-notices.txt"
SCOPE = "intent-scope.md"
OTHER_TEAMS = ot.FILE
OUT1 = "intent-critic-1.txt"
OUT2 = "intent-critic-2.txt"
# 칸 사본 — 호출마다의 칸(차례대로)과 그 원본. k=2(둘째 · 한 번에 넣은 호출)만 의심을 싣는다.
SLOT_COPY = "intent-slot-%d-%s.md"
SLOT_NAMES = {1: ("diff", "scope", "evidence", "origin", "roadmap", "intent", "answered"),
              2: ("diff", "scope", "evidence", "origin", "roadmap", "intent", "doubts", "answered")}
SLOT_SOURCES = {"diff": "review-i1.diff", "scope": SCOPE, "evidence": EVIDENCE, "origin": ORIGIN,
                "roadmap": ROADMAP, "intent": INTENT, "doubts": DOUBTS, "answered": ANSWERED}
QUESTIONS = "intent-questions.yaml"
RETURN = "intent-return.md"
RESULT = "result.md"

FENCE = "```qg-intent-critic"
RETURN_FENCE = "```qg-intent-return"
CAP = 3
WEIGHTS = {"방향": 0, "기능": 1, "동작": 2}
FILTER_ANSWERS = ("의도다", "잘못 골랐다")
# 답 입력의 머리 줄 — `=== n: <번호> · id: <정체> · pick: <고른 것>`. 「답 머리 꼴」 은 HEADER_SHAPES 로
# 시작하는 줄뿐이다(옛 `=== id: ` 꼴은 받지 않고 정체가 맞지 않는 머리로 센다).
HEADER = "=== n: "
ID_SEP = " · id: "
PICK_SEP = " · pick: "
HEADER_SHAPES = ("=== n: ", "=== id: ")
DIGITS = set("0123456789")
TYPED = "typed"
SECTION = "## intent-critic"
SECTION_LEAD = ("intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · "
                "동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다.")
RENDERED = "intent-rendered.txt"
FIRST_CANDIDATES = "## 첫째 호출의 후보"
INTENT_DOUBTS_MARK = "<!-- intent-doubts -->"
ALIAS_SEP = " -> "
NAMES_PREFIX = "review-i"
NAMES_SUFFIX = ".names"
# review-diff.sh 가 반복마다 남기는 그 실행의 --mode 한 줄. filter 는 이 다섯 낱말과 글자 그대로 같을 때만 쓴다.
MODE_SUFFIX = ".mode"
NAMES_MISSING = ("바뀐 파일 목록(review-i<N>.names)이 없거나 비어 이 범위가 더한 답 파일을 "
                 "가리지 못함")
# 바뀐 파일 목록이 리뷰 범위가 바꾼 경로를 모두 담는 모드. paths 의 목록은 glob 에 맞는 경로뿐이다.
WHOLE_SCOPE_MODES = ("session", "branch", "topic", "range")
REVIEW_MODES = WHOLE_SCOPE_MODES + ("paths",)
NAMES_PARTIAL = ("리뷰 범위가 paths 이거나 알 수 없어, 바뀐 파일 목록에 없는 답 파일은 이 범위가 "
                 "더했는지 가리지 못함")
RANGE_ADDED = "이 범위가 더한 답 파일"
RANGE_UNKNOWN = "범위 변경 여부를 확인하지 못함"
RANGE_MARKS = {"added": " · " + RANGE_ADDED, "unknown": " · " + RANGE_UNKNOWN}
COMMIT_MESSAGE = "docs(qg-intent): intent-critic 답 %d개 기록"
RECORD_FAILED = "답 기록 실패 %d개 — %s"
MISMATCHED = "정체가 맞지 않는 답 머리 %d개"
MISMATCH_FAILURE = "정체가 맞지 않는 답 머리"
DUPLICATE_HEADERS = "같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 %d개"
NO_HEADER = "답 입력에서 묻는 질문의 머리를 찾지 못함 — 묻는 질문 %d개"
ORPHAN = "머리 앞의 답 글을 읽지 못함 %d줄"
KILL_RECORD = "%s — 답 파일을 쓰지 않고 커밋하지 않았다"
KILL_FAILURE = "kill switch(%s)가 켜져 있어 기록하지 않음"
# 기록되지 않은 답의 질문마다 한 줄 — 공시로 사람에게 보이는 글이다. 돌려주는 꼴도 그 답을 싣는다(질문의 `answer` · `failure`).
RECORD_FAILED_ITEM = "답 기록 실패 질문 — %s · 고른 답: %s · 질문: %s"
PICK_UNREAD = "답을 읽지 못함"
SNIPPET = 80
UNANSWERED = " · 답하지 않음 %d개"

NO_EVIDENCE = "intent-critic — 근거 없음"
NO_QUESTION = "intent-critic — 질문 없음"
# 넓게 보는 리뷰에서만 — 낸 후보가 근거 확인(evidence · quote · read_only)에서 모두 걸러졌을 때.
ALL_FILTERED = "intent-critic — 낸 후보 %d개가 근거 확인에서 모두 걸러짐"
FILTERED_KEYS = ("evidence", "quote", "read_only")
UNREADABLE = "intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)"
ALREADY = "intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다"
SECOND_FAILED = "둘째 호출 출력을 읽지 못함 — 첫째 호출의 후보만 쓴다"

# 길 → (건너뜀 줄, 사유 글, 상태, 부호)
GATE_SKIPS = {
    "aborted": ("intent-critic — 건너뜀(멈춘 실행)", "멈춘 실행", "skipped", "halted"),
    "trivia": ("intent-critic — 건너뜀(작은 수정 — trivia)", "작은 수정 — trivia",
               "skipped", "trivia"),
    "scope-empty": ("intent-critic — 건너뜀(리뷰할 diff 없음)", "리뷰할 diff 없음",
                    "skipped", "empty-diff"),
    "tree-failed": ("intent-critic — 리뷰 트리를 만들지 못함", "리뷰 트리를 만들지 못함",
                    "failed", "tree-failed"),
}
KILL_LINE = "intent-critic 꺼짐(kill switch)"
GLOBAL_KILL_ENV = "DEVBREW_QUALITY_GATES_DISABLE"

# 돌려주는 꼴 3판 — 닫힌 어휘와 칸 차례.
CONTRACT = 3
RETURN_KEYS = ("contract", "status", "reason", "reason_text", "outcome", "result_line",
               "none_reason", "mode", "reviewed_head", "reviewed_base", "session_dir",
               "answers_dir", "answers_dir_source", "commit", "breadth", "other_teams",
               "overlaps", "answered_filtered")
QUESTION_KEYS = ("n", "id", "state", "answer", "answer_text", "wrong_choice", "failure", "file",
                 "evidence", "question", "target_source", "target_id", "label", "quote",
                 "observation", "why", "asked_before", "changed_observation")
# 이미 답해 거른 상태 — 넘겨받은 「잘못 골랐다」 가 이 에픽 밖으로 미뤄 둔 의심이면 deferred-filtered.
FILTERED_STATES = ("answered-filtered", "wrong-choice-filtered", "deferred-filtered")
DEFERRED_ROUTES = ("새 일의 씨앗", "재분해 신호")
REASK_CHANGED = "근거가 달라짐"
REASK_FIXED = "고친 뒤에도 보임"
PREVIOUS_OBSERVATION = "이전 관찰: "
HANDED_MARK = "넘겨받은 답"
DEFERRED_MARK = "미뤄 둔 의심"
IDENTITY_DIFFERS = "정체가 다름 — %s → %s"
RETURN_STATUSES = ("ran", "uncountable", "skipped", "failed")
SKIP_REASONS = ("kill-switch", "halted", "trivia", "empty-diff", "no-evidence")
FAIL_REASONS = ("tree-failed",)
RETURN_OUTCOMES = ("questions", "none", "no-evidence", "all-filtered")

# 거름 공시 — 0 이 아닌 것만 이 순서로 낸다.
COUNT_NOTICES = (
    ("evidence", "근거 없어 거름 %d"),
    ("quote", "인용이 그 파일에 없어 거름 %d"),
    ("read_only", "읽은 인용만 있어 거름 %d"),
    ("answered", "이미 답한 질문이라 거름 %d"),
    ("over_cap", "상한 넘어 남김 %d"),
    ("unidentified", "정체를 가르지 못함 %d"),
    ("broken", "항목 파손 %d"),
    ("absorbed", "두 호출에서 겹친 후보를 합침 %d"),
    ("cites_dropped", "근거로 받지 않은 인용 %d"),
)
QUESTION_STATES = ("답함", "답 기록 실패", "답하지 않음", "묻지 않음", "상한 넘어 남김")
NOT_ASKED_RANGE = "intent-critic — 질문 %d개 묻지 않음(범위 모드)"
NOT_ASKED_EARLY = "intent-critic — 질문 %d개 묻지 않음(묻기 전에 끝남)"
TABLE_HEAD = "| 정체 | 상태 | 근거 | 답 | 답 파일 | 질문 |"
KIND_SEP = " · "
# 결과 절의 다른 팀 목록 — 리뷰어를 부르지 않은 실행에도 늘 보인다.
OVERLAP_HEAD = "다른 팀과 겹치는 곳:"
UNVERIFIED_HEAD = "다른 팀 확인 못 함:"
NO_TEAMS_RECORD = "- 다른 팀 기록 없음"
TEAMS_UNREAD = "- 기록에서 이 절을 읽지 못함"


class InputError(Exception):
    """입력 파일을 읽지 못했다 — prepare 는 rc 4 로 끝난다."""


# ---------------------------------------------------------------- 파일

def _path(rd: str, name: str) -> str:
    return os.path.join(rd, name)


def _read(path: str) -> Optional[str]:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


# UTF-8 로 쓸 수 없는 글자(짝 없는 surrogate — YAML 의 `"\\ud800"` 이 그렇게 읽힌다)는 버리지 않고
# `\\ud800` 꼴로 남긴다. 리뷰 트리의 답 파일 · 리뷰어 출력에서 온 그런 글이 단계를 죽이지 못한다.
UNWRITABLE = "backslashreplace"


def _write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", errors=UNWRITABLE) as fh:
        fh.write(text)


def _append(path: str, text: str) -> None:
    with open(path, "a", encoding="utf-8", errors=UNWRITABLE) as fh:
        fh.write(text)


def _emit(lines: List[str]) -> None:
    for line in lines:
        print(line)


def _key_values(text: Optional[str]) -> List[tuple]:
    """`키: 값` 줄들 → [(키, 값)] (순서대로, 같은 키 여럿 허용)."""
    out = []
    for line in (text or "").splitlines():
        key, sep, value = line.partition(": ")
        if sep and key.strip():
            out.append((key.strip(), value.strip()))
    return out


def _repeated(pairs: List[tuple], keys: tuple) -> bool:
    """한 번만 와야 하는 키가 두 번 이상 왔나 — 덧쓴 줄은 마지막 것이 이기게 두지 않고 파일을 거부한다."""
    seen: dict = {}
    for key, _value in pairs:
        if key in keys:
            seen[key] = seen.get(key, 0) + 1
    repeated = False
    for key in seen:
        if seen[key] > 1:
            repeated = True
    return repeated


CONFIG_KEYS = ("answers_dir", "answers_dir_source", "max_bytes", "max_bytes_source",
               "other_teams_max_bytes", "other_teams_max_bytes_source", "intent_doc_markers",
               "intent_doc_markers_source")
PLAN_KEYS = ("call", "mode", "tree_root", "answers_root", "breadth", "reviewed_head",
             "reviewed_base")
# 리뷰의 넓이 — narrow 는 R1 그대로, 뒤 둘이 넓게 보는 리뷰다. 계획 파일에 없거나 모르는 값이면 narrow.
BREADTHS = ("narrow", "range", "intent-docs")


def _read_config(rd: str) -> Optional[dict]:
    pairs = _key_values(_read(_path(rd, CONFIG)))
    if _repeated(pairs, CONFIG_KEYS):
        return None
    cfg = dict(pairs)
    if not cfg.get("answers_dir") or not cfg.get("max_bytes", "").isdigit():
        return None
    cfg["max_bytes"] = int(cfg["max_bytes"])
    # R2 가 더한 키 — 없으면(옛 꼴) 기본값, 있는데 틀리면 파일을 거부한다. 짝 `_source` 없이 하나만 와도 받는다.
    other_max = cfg.get("other_teams_max_bytes")
    cfg["other_teams_max_bytes"] = (DEFAULT_OTHER_MAX if other_max is None
                                    else _valid_max_bytes(other_max))
    markers = cfg.get("intent_doc_markers")
    cfg["intent_doc_markers"] = (list(io_.DEFAULT_MARKERS) if markers is None
                                 else io_.parse_markers(markers))
    if cfg["other_teams_max_bytes"] is None or cfg["intent_doc_markers"] is None:
        return None
    return cfg


def _read_plan(rd: str) -> Optional[dict]:
    text = _read(_path(rd, PLAN))
    if text is None:
        return None
    pairs = _key_values(text)
    if _repeated(pairs, PLAN_KEYS):
        return None
    plan = {"call": "", "mode": "", "tree_root": "", "answers_root": "", "breadth": "narrow",
            "reviewed_head": "-", "reviewed_base": "-", "sources": [], "aliases": {}}
    for key, value in pairs:
        if key == "source":
            plan["sources"].append(value)
        elif key == "alias":
            bundle, sep, brief = value.rpartition(ALIAS_SEP)
            if sep:
                plan["aliases"][bundle] = brief
        elif key in PLAN_KEYS:
            plan[key] = value
    if plan["breadth"] not in BREADTHS:
        plan["breadth"] = "narrow"
    return plan


def _read_questions(rd: str) -> Optional[dict]:
    text = _read(_path(rd, QUESTIONS))
    if text is None:
        return None
    try:
        data = yaml.safe_load(text)
    except Exception:  # noqa: BLE001 — YAMLError 말고도(없는 날짜의 ValueError 등) 읽지 못한 파일이다
        return None
    if not isinstance(data, dict) or not isinstance(data.get("questions"), list):
        return None
    return data


def _write_questions(rd: str, data: dict) -> None:
    _write(_path(rd, QUESTIONS), yaml.safe_dump(data, allow_unicode=True, sort_keys=False))


# ---------------------------------------------------------------- 돌려주는 꼴

_PLAIN_BAD_START = "-?:,[]{}#&*!|>'\"%@` 0123456789.+~"


def _reads_back(text: str) -> bool:
    """YAML 로 읽으면 같은 글이 돌아오나 — 수 · 참거짓 · null 로 읽히는 글(`true` · `null` …)은 아니다."""
    try:
        return yaml.safe_load(text) == text
    except Exception:  # noqa: BLE001 — YAMLError 말고도 예외를 낸다(틀린 태그 · 수 등)
        return False


def _scalar(value) -> str:
    """YAML 한 줄 값 — 글자 그대로 읽히는 글은 그대로, 아니면 큰따옴표로 감싼다.

    숫자로 시작하는 글(숫자뿐인 짧은 커밋 해시 등)은 수로 읽히지 않게 늘 감싼다.
    """
    text = "" if value is None else str(value)
    plain = (text != "" and text[0] not in _PLAIN_BAD_START and ": " not in text
             and " #" not in text and "\n" not in text and not text.endswith((" ", ":"))
             and _reads_back(text))
    return text if plain else json.dumps(text, ensure_ascii=False)


def _text_cell(value) -> str:
    """글 칸 — 한 줄로 접어 큰따옴표로 싼다."""
    return json.dumps(_one_line(value), ensure_ascii=False)


def _write_return(rd: str, head: dict, rows: List[dict]) -> None:
    """돌려주는 꼴 3판. `head` 에 없는 칸은 `-`. `overlaps` 는 겹침 수(정수 — 날 수로) 또는 모름 `-`,
    `answered_filtered` 는 이미 답해 거른 수(정수) 또는 건너뜀 · 셀 수 없음 `-`."""
    cfg = _read_config(rd) or {}
    values = dict(head)
    values["contract"] = CONTRACT
    values["session_dir"] = os.path.abspath(rd)
    values["answers_dir"] = cfg.get("answers_dir", "-")
    values["answers_dir_source"] = cfg.get("answers_dir_source", "-")
    lines = [RETURN_FENCE]
    for key in RETURN_KEYS:
        value = values.get(key)
        if key in ("reason_text", "result_line", "none_reason", "session_dir"):
            lines.append("%s: %s" % (key, _text_cell(value if value else "-")))
        elif key == "contract" or (key in ("overlaps", "answered_filtered") and type(value) is int):
            lines.append("%s: %d" % (key, value))
        else:
            lines.append("%s: %s" % (key, _scalar(value if value else "-")))
    if not rows:
        lines.append("questions: []")
    else:
        lines.append("questions:")
    for row in rows:
        lines.append("  - n: " + (str(row["n"]) if type(row.get("n")) is int else _scalar("-")))
        for key in QUESTION_KEYS[1:]:
            value = row.get(key)
            if key == "state":
                lines.append("    state: " + _scalar(value))
            elif key == "wrong_choice":
                lines.append("    wrong_choice: " + ("true" if value else "false"))
            elif key in ("answer_text", "observation", "changed_observation"):
                if not isinstance(value, list) or not value:
                    lines.append("    %s: %s" % (key, "[]" if key == "observation" else _text_cell("-")))
                else:
                    lines.append("    %s:" % key)
                    for item in value:
                        lines.append("      - " + _text_cell(item))
            else:
                lines.append("    %s: %s" % (key, _text_cell(value if value else "-")))
    lines.append("```")
    _write(_path(rd, RETURN), "\n".join(lines) + "\n")


# ---------------------------------------------------------------- gate

def _switches_on() -> List[str]:
    """켜진(`== "1"`) 끄기 스위치 변수 이름 — 전역이 앞이다."""
    on: List[str] = []
    for name in (GLOBAL_KILL_ENV, KILL_ENV):
        if os.environ.get(name) == "1":
            on.append(name)
    return on


def _kill_names(names: List[str]) -> str:
    """`<변수>=1` 을 ` · ` 로 이은 글 — 전역이 앞이다."""
    parts = []
    for name in names:
        parts.append(name + "=1")
    return " · ".join(parts)


def _kill_text(names: List[str]) -> str:
    return "intent-critic 꺼짐(kill switch — %s)" % _kill_names(names)


def _killed(rd: str, mode: str, stale=()) -> bool:
    """kill switch 가 켜졌으면 꺼짐 처리(`stale` 세션 파일 지우기 · 돌려주는 꼴 · 꺼짐 줄)를 하고 참.

    `gate` 와 `prepare` 가 함께 쓴다 — 두 자리의 꺼짐 출력이 갈라지지 않게.
    """
    names = _switches_on()
    if not names:
        return False
    for name in stale:
        _remove(_path(rd, name))
    _write_return(rd, {"status": "skipped", "reason": "kill-switch",
                       "reason_text": _kill_text(names), "outcome": "-",
                       "result_line": KILL_LINE, "mode": mode}, [])
    print(KILL_LINE)
    return True


def cmd_gate(args) -> int:
    if _killed(args.rd, args.mode):
        return 0
    if args.path == "final":
        print("intent-gate: run")
        return 0
    line, reason_text, status, reason = GATE_SKIPS[args.path]
    _write_return(args.rd, {"status": status, "reason": reason, "reason_text": reason_text,
                            "outcome": "-", "result_line": line, "mode": args.mode}, [])
    print(line)
    return 0


# ---------------------------------------------------------------- config

def _git_show(repo: str, rev: str, rel: str) -> Optional[str]:
    if rev == "-":
        return None
    try:
        res = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (rev, rel)],
                             capture_output=True)
    except OSError:
        return None
    if res.returncode != 0:
        return None
    return res.stdout.decode("utf-8", "replace")


def _git_ignored(project_dir: str, rel: str) -> bool:
    try:
        res = subprocess.run(["git", "-C", project_dir, "check-ignore", "-q", "--", rel],
                             capture_output=True)
    except OSError:
        return False
    return res.returncode == 0


def _settings_pairs(repo: str, base: str, project_dir: str) -> List[tuple]:
    """(base 쪽 글, 리뷰 트리 쪽 글) — git 이 무시하는 리뷰 트리 쪽 파일은 base 와 같은 글로 본다."""
    pairs = []
    for rel in SETTINGS_FILES:
        base_text = _git_show(repo, base, rel)
        if _git_ignored(project_dir, rel):
            head_text = base_text
        else:
            head_text = _read(os.path.join(project_dir, rel))
        pairs.append((base_text, head_text))
    return pairs


def _settings_changed(pairs: List[tuple], key: str) -> bool:
    changed = False
    for base_text, head_text in pairs:
        if doc_paths.settings_key_changed(base_text, head_text, key=key):
            changed = True
    return changed


def _valid_answers_dir(raw: str) -> Optional[str]:
    value = raw.strip().rstrip("/")
    if not value or value.startswith(("/", ":")) or "\\" in value:
        return None
    ok = True
    parts = value.split("/")
    for part in parts:
        # 대소문자를 가리지 않는 파일 시스템에서는 `.GIT` 이 `.git` 이다 — 글자 크기를 접어 견준다.
        if part in ("", ".", "..") or part.casefold() == ".git" or not part.isprintable():
            ok = False
    if not ok or parts[0].casefold() == ".claude":
        return None
    return value


def _valid_max_bytes(raw: str) -> Optional[int]:
    value = raw.strip()
    if not value.isdigit() or not value.isascii() or int(value) <= 0:
        return None
    return int(value)


def _setting(pairs, key, default, validate) -> tuple:
    if _settings_changed(pairs, key):
        return default, "default-settings-changed"
    raw = os.environ.get(key)
    if raw is None:
        return default, "default"
    value = validate(raw)
    if value is None:
        return default, "default-invalid"
    return value, "env"


def cmd_config(args) -> int:
    pairs = _settings_pairs(args.repo, args.base, args.project_dir)
    answers_dir, dir_source = _setting(pairs, DIR_ENV, DEFAULT_DIR, _valid_answers_dir)
    max_bytes, max_source = _setting(pairs, MAX_ENV, DEFAULT_MAX, _valid_max_bytes)
    other_max, other_source = _setting(pairs, OTHER_MAX_ENV, DEFAULT_OTHER_MAX, _valid_max_bytes)
    markers, markers_source = _setting(pairs, MARKERS_ENV, list(io_.DEFAULT_MARKERS),
                                       io_.parse_markers)
    lines = ["answers_dir: %s" % answers_dir, "answers_dir_source: %s" % dir_source,
             "max_bytes: %d" % max_bytes, "max_bytes_source: %s" % max_source,
             "other_teams_max_bytes: %d" % other_max,
             "other_teams_max_bytes_source: %s" % other_source,
             "intent_doc_markers: %s" % ",".join(markers),
             "intent_doc_markers_source: %s" % markers_source]
    _write(_path(args.rd, CONFIG), "\n".join(lines) + "\n")
    _emit(lines)
    return 0


# ---------------------------------------------------------------- prepare

def _parse_specs(text: str, notices: List[str]) -> List[str]:
    try:
        data = json.loads(text)
    except ValueError:
        data = None
    specs = data.get("specs") if isinstance(data, dict) else None
    if not isinstance(specs, list):
        notices.append("의도 출처 JSON 을 읽지 못함")
        return []
    out = []
    for spec in specs:
        if isinstance(spec, str) and spec:
            out.append(spec)
    return out


def _answered_cell(value) -> str:
    return _one_line(value) or "-"


def _answered_lines(answered: dict, handed: List[dict]) -> str:
    lines = []
    for ident in sorted(answered):
        entry = answered[ident]
        first = (entry["observation"].strip().splitlines() or ["-"])[0]
        lines.append("- %s · %s · 질문: %s · 관찰: %s" % (
            _answered_cell(ident), _answered_cell(entry["answer"]), _answered_cell(entry.get("question", "")), _answered_cell(first)))
    for entry in handed:
        first = (entry["observation"].strip().splitlines() or ["-"])[0]
        lines.append("- %s · %s · %s · 질문: %s · 관찰: %s" % (
            _answered_cell(entry["key"]), _answered_cell(entry["id"]), _answered_cell(entry["answer"]),
            _answered_cell(entry["question"]), _answered_cell(first)))
    if not lines:
        return "답한 질문 없음\n"
    return "\n".join(lines) + "\n"


def _add_notice(notices: List[str], line: str) -> None:
    if line not in notices:
        notices.append(line)


def _plan_value_ok(value) -> bool:
    return isinstance(value, str) and value != "" and io_.single_line(value)


def _line_ok(key: str, value) -> bool:
    """`키: 값` 한 줄로 써서 읽으면 같은 (키, 값) 하나가 돌아오나 — 한 줄 · 제어 문자 없음 · 앞뒤 공백 없음."""
    return _plan_value_ok(value) and _key_values(key + ": " + value) == [(key, value)]


def _write_plan(rd: str, call: str, mode: str, tree_root: str, answers_root: str, sources,
                aliases, notices: List[str], breadth: str = "narrow",
                reviewed: tuple = ("-", "-")) -> None:
    """줄 단위 계획 파일. 줄마다 써서 다시 읽으면 같은 값이 나오는지 확인하고, 아닌 출처 · 별칭은 쓰지 않고 공시한다."""
    singles = (("call", call), ("mode", mode), ("tree_root", tree_root),
               ("answers_root", answers_root), ("breadth", breadth),
               ("reviewed_head", reviewed[0]), ("reviewed_base", reviewed[1]))
    lines = []
    for key, value in singles:
        if not _line_ok(key, value):
            raise InputError("계획 값 %s 에 %s가 있다" % (key, io_.REASON_CONTROL))
        lines.append("%s: %s" % (key, value))
    for source in sources:
        if _line_ok("source", source):
            lines.append("source: " + source)
        else:
            _add_notice(notices, "의도 출처 경로 거부 — " + io_.REASON_CONTROL)
    for bundle in sorted(aliases):
        joined = "%s%s%s" % (bundle, ALIAS_SEP, aliases[bundle])
        if (_line_ok("alias", joined)
                and joined.rpartition(ALIAS_SEP) == (bundle, ALIAS_SEP, aliases[bundle])):
            lines.append("alias: " + joined)
        else:
            notices.append("묶음 별칭 거부 — ' -> ' 또는 제어 문자")
    _write(_path(rd, PLAN), "\n".join(lines) + "\n")


NOTICE_NO_NAMES = "바뀐 파일 목록이 없어 넓게 보지 않는다"
NOTICE_UNREAD_DOCS = "의도 문서인지 확인 못 한 문서 %d — 추적되지 않는다"
NOTICE_TIMED_OUT_DOCS = "의도 문서인지 확인 못 한 문서 %d — " + io_.REASON_TIMEOUT
NOTICE_NO_TREE = "리뷰 트리가 없어 읽은 인용을 확인하지 못함"
NOTICE_TEAMS_FAILED = "다른 팀 읽기 실패 — %s"
NOTICE_BYTES = "입력 %d바이트 · 다른 팀 기록 %d바이트(상한 %d — 나눠 부르기 판정에 넣지 않는다)"


def _breadth(args, tree_root: str, cfg: dict, notices: List[str]) -> tuple:
    """(바뀐 파일 목록 | None, 넓이, 바뀐 의도 문서들). 바뀐 문서는 리뷰 트리에서 읽는다."""
    names = _range_names(args.rd)
    timed_out: List[str] = []
    breadth, docs, unread = io_.review_breadth(
        args.mode, names, lambda rel: io_.read_changed_doc(tree_root, rel, timed_out),
        cfg["intent_doc_markers"])
    if args.mode == "range" and names is None:
        _add_notice(notices, NOTICE_NO_NAMES)
    if breadth != "narrow":
        _add_notice(notices, io_.BREADTH_LABELS[breadth])
    if unread - len(timed_out):
        _add_notice(notices, NOTICE_UNREAD_DOCS % (unread - len(timed_out)))
    if timed_out:
        _add_notice(notices, NOTICE_TIMED_OUT_DOCS % len(timed_out))
    return names, breadth, docs


def _topic_siblings(rd: str) -> Optional[set]:
    """토픽 리뷰의 형제 브랜치 이름들 — `topic-scope.txt` 의 `status:` 가 `ok` 이고 `branches:` 가
    `-` 아닌 쉼표 목록일 때만. 그 밖에는 None(아무것도 빼지 않는다)."""
    text = _read(_path(rd, "topic-scope.txt"))
    if text is None:
        return None
    status = None
    branches = None
    for line in text.split("\n"):
        key, sep, value = line.partition(":")
        if sep and key == "status" and status is None:
            status = value.strip()
        elif sep and key == "branches" and branches is None:
            branches = value.strip()
    if status != "ok" or not branches or branches == "-":
        return None
    names = set()
    for piece in branches.split(","):
        if piece.strip():
            names.add(piece.strip())
    return names or None


def _teams(args, names, roadmaps, cfg, siblings=None, collect=ot.collect) -> tuple:
    """다른 팀 기록 → (글, 공시 줄들). 읽기가 예외로 끝나도 단계를 멈추지 않는다(fail-open — 공시한다)."""
    try:
        got = collect(args.repo, os.path.abspath(args.tree_root), args.review_commit, names,
                      roadmaps, cfg["intent_doc_markers"], cfg["other_teams_max_bytes"],
                      siblings=siblings)
        return got["text"], list(got["notices"])
    except Exception as exc:  # noqa: BLE001 — 어떤 실패든 이름만 공시하고 다른 팀 없이 간다
        return "", [NOTICE_TEAMS_FAILED % type(exc).__name__]


def _remove(path: str) -> None:
    try:
        os.remove(path)
    except OSError:
        pass


def _prepare(args, notices: List[str]) -> str:
    rd = args.rd
    if not os.path.isdir(rd):
        raise InputError("세션 폴더가 없다: %s" % rd)
    cfg = _read_config(rd)
    if cfg is None:
        raise InputError("%s 를 읽지 못했다 — config 를 먼저 돈다" % CONFIG)
    specs_text = _read(args.specs_json)
    if specs_text is None:
        raise InputError("의도 출처 JSON 파일을 읽지 못했다: %s" % args.specs_json)
    specs = _parse_specs(specs_text, notices)
    tree_root = os.path.abspath(args.tree_root)
    answers_root = os.path.join(tree_root, cfg["answers_dir"])

    names, breadth, docs = _breadth(args, tree_root, cfg, notices)
    # PR 범위의 리뷰 커밋은 글자 HEAD 로 오고 답 커밋이 HEAD 를 옮긴다 — 지금 해시로 풀어 둔다.
    reviewed = (_resolve_commit(args.repo, args.review_commit),
                _resolve_commit(args.repo, args.base))
    built = io_.build_origin(args.repo, args.head, args.review_commit, args.origin, specs,
                             changed_docs=docs, tree_root=tree_root)
    teams_text, teams_notices = _teams(args, names, built["roadmaps"], cfg,
                                     _topic_siblings(rd))
    if teams_text:
        _write(_path(rd, OTHER_TEAMS), teams_text)
    else:
        _remove(_path(rd, OTHER_TEAMS))
    # 기록을 썼으면 공시는 상한 줄뿐이다 — 리뷰어에게 실은 것을 말하니 부르지 않는 실행에서는 뺀다.
    cap_lines = teams_notices if teams_text else []
    for line in teams_notices:
        _add_notice(notices, line)
    _write(_path(rd, SCOPE), io_.render_scope(breadth, names, args.repo, args.base,
                                              args.review_commit))

    e2e = _read(_path(rd, "e2e-record.md"))
    differential = _read(_path(rd, "differential.yaml"))
    ok, evidence_notices = io_.has_evidence(e2e, differential)
    for line in evidence_notices:
        _add_notice(notices, line)
    # 좁은 리뷰는 R1 그대로 돌려 본 근거가 있을 때만 부른다 — 이때 원문 조립의 공시는 내지 않는다.
    if not ok and breadth == "narrow":
        for line in cap_lines:  # 상한 줄은 기록의 `## 상한` 에 남는다 — 출력은 R1 그대로
            if line in notices:
                notices.remove(line)
        _add_notice(notices, NO_EVIDENCE)
        _remove(_path(rd, HANDED))  # 리뷰어를 부르지 않는 실행 — 앞 실행의 복사본을 남기지 않는다
        _write_plan(rd, "none", args.mode, tree_root, answers_root, [], {}, notices,
                    breadth=breadth, reviewed=reviewed)
        return "none"

    run_text, _count = io_.build_evidence(e2e, differential)
    evidence, _count = io_.build_evidence(e2e, differential, teams_text)
    for line in built["notices"]:
        _add_notice(notices, line)
    if built["mixed"]:
        _add_notice(notices, "첫 호출에 의심이 섞였다")

    intent_text = _read(_path(rd, "intent.md"))
    if intent_text is None:
        intent_kept, intent_moved = "의도 출처 없음 — intent.md 를 읽지 못함\n", ""
        _add_notice(notices, "의도 출처 없음 — intent.md 를 읽지 못함")
    else:
        intent_kept, intent_moved = io_.strip_intent_doubts(intent_text)
    doubts = built["doubts"]
    if intent_moved.strip():
        if doubts and not doubts.endswith("\n"):
            doubts += "\n"
        doubts += INTENT_DOUBTS_MARK + "\n" + io_.neutralize_markers(intent_moved)

    answered, unreadable, why = ia.read_answered_under(tree_root, cfg["answers_dir"])
    if why:
        _add_notice(notices, "답 자리를 읽지 않았다 — " + why)
    if unreadable:
        _add_notice(notices, "읽지 못한 답 파일 %d" % unreadable)

    # 나눠 부르기 판정은 돌려 본 줄로만 한다 — 다른 팀 기록은 자기 상한으로 묶이고 재서 공시한다.
    total = io_.total_bytes(run_text, built["origin"], built["roadmap"], intent_kept, doubts)
    if total > cfg["max_bytes"]:
        call = "single"
        _add_notice(notices, "한 번에 넣음 — 입력 %d바이트가 상한 %d바이트를 넘었다"
                    % (total, cfg["max_bytes"]))
    elif not doubts.strip():
        call = "first-only"
    else:
        call = "split"
    _add_notice(notices, NOTICE_BYTES % (total, io_.teams_bytes(evidence),
                                         cfg["other_teams_max_bytes"]))

    _write(_path(rd, EVIDENCE), evidence)
    _write(_path(rd, ORIGIN), built["origin"])
    _write(_path(rd, ROADMAP), built["roadmap"])
    _write(_path(rd, INTENT), intent_kept)
    _write(_path(rd, DOUBTS), doubts)
    handed: List[dict] = []
    if args.answered:
        entries, handed_why = ia.read_handed(args.answered)
        if entries is None:
            _add_notice(notices, HANDED_UNREAD + str(handed_why))
        else:
            handed = entries
    if handed:
        _write(_path(rd, HANDED), yaml.safe_dump({"entries": handed}, allow_unicode=True,
                                                 sort_keys=False))
    else:
        _remove(_path(rd, HANDED))
    _write(_path(rd, ANSWERED), _answered_lines(answered, handed))
    _write_plan(rd, call, args.mode, tree_root, answers_root, built["sources"],
                built["aliases"], notices, breadth=breadth, reviewed=reviewed)
    return call


def _persist_prepare_notices(rd: str, notices: List[str]) -> None:
    """공시 줄을 세션 파일에 남긴다 — 한 줄로 읽히는 것만, 결과 줄과 겹치는 근거 없음 줄은 뺀다."""
    text = ""
    for line in notices:
        if io_.single_line(line) and line != NO_EVIDENCE:
            text += line + "\n"
    _write(_path(rd, PREPARE_NOTICES), text)


def _prepare_notices(rd: str) -> List[str]:
    out = []
    for line in (_read(_path(rd, PREPARE_NOTICES)) or "").splitlines():
        if line.strip():
            out.append(line)
    return out


def cmd_prepare(args) -> int:
    # gate 를 거치지 않고 불려도 스위치가 넓이 판정 · 다른 팀 읽기 · gh 조회를 끈다 — 앞 실행의 두 파일도 지운다.
    if _killed(args.rd, args.mode, stale=(OTHER_TEAMS, SCOPE, HANDED)):
        return 0
    notices: List[str] = []
    try:
        call = _prepare(args, notices)
    except InputError as exc:
        sys.stderr.write("intent_critic prepare: %s\n" % exc)
        return 4
    _persist_prepare_notices(args.rd, notices)
    _emit(notices)
    print("intent-call: " + call)
    return 0


# ---------------------------------------------------------------- 리뷰어 출력

def _fence_bodies(text: str) -> tuple:
    """(qg-intent-critic 펜스 본문들, 닫히지 않은 펜스가 있나)."""
    bodies: List[str] = []
    current: Optional[List[str]] = None
    for line in text.splitlines():
        stripped = line.strip()
        if current is None:
            if stripped == FENCE:
                current = []
        elif stripped == "```":
            bodies.append("\n".join(current))
            current = None
        else:
            current.append(line)
    return bodies, current is not None


def _parse_output(text: Optional[str]) -> tuple:
    """(dict | None, 읽지 못한 사유)."""
    if text is None:
        return None, "파일을 읽지 못함"
    bodies, unclosed = _fence_bodies(text)
    if unclosed:
        return None, "qg-intent-critic 펜스가 닫히지 않음"
    if not bodies:
        return None, "qg-intent-critic 펜스가 없음"
    if len(bodies) > 1:
        return None, "qg-intent-critic 펜스가 둘 이상"
    try:
        data = yaml.safe_load(bodies[0])
    except Exception:  # noqa: BLE001 — 리뷰어가 옮긴 글(날짜 꼴 등)이 YAMLError 아닌 예외를 낸다
        return None, "펜스 안 YAML 을 읽지 못함"
    if not isinstance(data, dict) or not isinstance(data.get("questions"), list):
        return None, "questions 목록이 없음"
    return data, ""


def parse_reviewer_output(text: str) -> Optional[dict]:
    """```qg-intent-critic 펜스가 정확히 하나이고 그 YAML 이 `questions` 목록을 가진 dict 면 그 dict."""
    data, _why = _parse_output(text)
    return data


def _slot_paths(rd: str, k: int) -> List[str]:
    return [_path(rd, SLOT_COPY % (k, slot)) for slot in SLOT_NAMES[k]]


def _checked_output(path: str, rd: str, k: int) -> tuple:
    """(dict | None, 사유, 끝 값 대조의 실패인가). 대조가 먼저다 — 칸 사본이 하나라도 없거나 그 끝 값이
    응답에 없으면 `끝 값 없음` · `읽지 못함`(qg_nonce.check)."""
    text = _read(path)
    if text is None:
        return None, "파일을 읽지 못함", False
    reason = qg_nonce.check(text, _slot_paths(rd, k))
    if reason is not None:
        return None, reason, True
    data, why = _parse_output(text)
    return data, why, False


def _call_why(label: str, why: str, slot_fail: bool) -> str:
    """실패 사유 — 끝 값 대조면 괄호(`첫째 호출(끝 값 없음)`), 그 밖이면 지금 꼴(`첫째 호출 — <사유>`)."""
    return "%s(%s)" % (label, why) if slot_fail else "%s — %s" % (label, why)


def cmd_slots(args) -> int:
    rd, k = args.rd, args.call
    written = []
    try:
        for slot in SLOT_NAMES[k]:
            out = _path(rd, SLOT_COPY % (k, slot))
            qg_nonce.attach(_path(rd, SLOT_SOURCES[slot]), out)
            written.append((slot, out))
    except qg_nonce.IoFail as exc:
        for slot in SLOT_NAMES[k]:
            _remove(_path(rd, SLOT_COPY % (k, slot)))
        sys.stderr.write("[intent_critic] 칸 사본을 쓰지 못했다(%s — %s) — 이 호출의 리뷰어를 부르지 "
                         "않는다\n" % (exc.reason, exc.path))
        return 4
    for slot, out in written:
        print("%s\t%s" % (slot, out))
    return 0


def cmd_check_output(args) -> int:
    path = os.path.abspath(args.file)
    data, why, _slot_fail = _checked_output(path, os.path.dirname(path), args.call)
    if data is None:
        print("unreadable: " + why)
        return 3
    print("readable")
    return 0


def cmd_doubts_append(args) -> int:
    data, why = _parse_output(_read(_path(args.rd, OUT1)))
    if data is None:
        print("첫째 호출 출력을 읽지 못함 — 덧붙이지 않았다(%s)" % why)
        print("doubts-append: 0")
        return 0
    path = _path(args.rd, DOUBTS)
    existing = _read(path) or ""
    count = len(data["questions"])
    dumped = io_.neutralize_markers(yaml.safe_dump({"questions": data["questions"]},
                                                   allow_unicode=True, sort_keys=False))
    block = "\n%s\n\n```yaml\n%s```\n" % (FIRST_CANDIDATES, dumped)
    # 이미 덧붙였는지는 파일 끝이 이 블록인지로 본다 — 의심 본문(리뷰 트리에서 온 글)에 같은
    # 머리 줄이 있어도 덧붙이기를 막지 못하게.
    if not existing.endswith(block):
        lead = "" if not existing or existing.endswith("\n") else "\n"
        _append(path, lead + block)
    print("doubts-append: %d" % count)
    return 0


# ---------------------------------------------------------------- filter

def _text(value) -> str:
    return "" if value is None else str(value)


def _evidence_lines(rd: str) -> dict:
    """줄 번호 → 근거 줄 글."""
    lines = {}
    for line in (_read(_path(rd, EVIDENCE)) or "").split("\n"):
        head = line.split("\t", 1)[0].strip()
        if head.isdigit():
            lines[int(head)] = line
    return lines


def _cited(numbers, evidence: dict) -> bool:
    if not isinstance(numbers, list) or not numbers:
        return False
    ok = True
    for n in numbers:
        if type(n) is not int or n not in evidence:
            ok = False
    return ok


def _identity(item: dict, plan: dict) -> Optional[str]:
    source = item.get("target_source")
    if isinstance(source, str) and source in plan["aliases"]:
        source = plan["aliases"][source]
    ident = ia.make_id(source, item.get("target_id"), item.get("kind"))
    if ident is None or (source != "diff" and source not in plan["sources"]):
        return None
    return ident


def _observation_changed(value, observation: str, evidence: dict, wide: bool,
                         tree_root: str) -> bool:
    """앞 답의 관찰이 바뀌었나 — 지금의 근거 줄이 맞거나, 넓은 리뷰에서 지금의 읽은 인용이 확인될 때.

    `previous` 는 원래 관찰에 있거나, 접은 꼴(`<answered>` 칸이 보이는 꼴)로 접은 관찰에 있으면 맞다.
    """
    if not isinstance(value, dict):
        return False
    previous = value.get("previous")
    if not isinstance(previous, str) or not previous.strip():
        return False
    folded = _one_line(previous)
    if previous not in observation and not (folded and folded in _one_line(observation)):
        return False
    if _cited(value.get("now_lines"), evidence):
        return True
    return wide and bool(io_.verify_quotes(tree_root, value.get("now_quotes"))[0])


def _changed_observation(value: dict, evidence: dict, wide: bool, tree_root: str) -> list:
    """다시 묻는 까닭이 「근거가 달라짐」 인 질문의 「달라진 관찰」 — 화면의 한 구절, 이전 관찰, 확인된 지금의
    근거 줄 · 읽은 인용. 한 구절은 확인된 첫 근거 줄(앞의 `<번호>\\t` 를 뗀 글), 없으면 확인된 첫 인용이다."""
    lines = list(value["now_lines"]) if _cited(value.get("now_lines"), evidence) else []
    quotes = io_.verify_quotes(tree_root, value.get("now_quotes"))[0] if wide else []
    now = []
    for n in lines:
        now.append(evidence[n])
    for quote in quotes:
        now.append(io_.quote_line(quote))
    if lines:
        first = evidence[lines[0]].split("\t", 1)[-1]
    else:
        first = now[0]
    return [_one_line(first, SNIPPET), PREVIOUS_OBSERVATION + _one_line(value["previous"])] + now


def _asked_before(answer: str, at: str, key: str, why: str) -> str:
    return KIND_SEP.join((_one_line(answer), _one_line(at), _one_line(key), why))


def _prior(item: dict, ident: Optional[str], answered: dict, handed: dict, evidence: dict,
           wide: bool, tree_root: str) -> Optional[dict]:
    """`same_as` 가 가리킨 지난 답 — {state: 거른 상태 | None, asked_before: 글 | "-",
    changed: 목록 | "-", handed: 넘겨받은 항목 | None}. 가리킨 답이 없으면 None(거르지 않는다).

    넘겨받은 열쇠를 먼저 본다(정체는 견주지 않는다). 답 폴더는 `same_as` 가 지금 정체일 때만 본다 —
    열쇠(`#` 하나)와 정체(`#` 둘)는 겹치지 않는다.
    """
    same = item.get("same_as")
    if not isinstance(same, str):
        return None
    value = item.get("observation_changed")
    entry = handed.get(same)
    if entry is not None:
        out = {"state": None, "asked_before": "-", "changed": "-", "handed": entry}
        if entry["answer"] == "잘못 골랐다" and entry["route"] not in DEFERRED_ROUTES:
            # 이 에픽 안에서 고치기로 한 의심 — 관찰과 무관하게 다시 묻는다.
            out["asked_before"] = _asked_before(entry["answer"], entry["answered_at"], same,
                                                REASK_FIXED)
        elif _observation_changed(value, entry["observation"], evidence, wide, tree_root):
            out["asked_before"] = _asked_before(entry["answer"], entry["answered_at"], same,
                                                REASK_CHANGED)
            out["changed"] = _changed_observation(value, evidence, wide, tree_root)
        elif entry["answer"] == "잘못 골랐다":
            out["state"] = "deferred-filtered"
        else:
            out["state"] = "answered-filtered"
        return out
    if ident is None or same != ident:
        return None
    prev = answered.get(ident)
    if prev is None or prev["answer"] not in FILTER_ANSWERS:
        return None
    out = {"state": None, "asked_before": "-", "changed": "-", "handed": None}
    if _observation_changed(value, prev["observation"], evidence, wide, tree_root):
        out["asked_before"] = _asked_before(prev["answer"], prev["answered_at"], ident,
                                            REASK_CHANGED)
        out["changed"] = _changed_observation(value, evidence, wide, tree_root)
    elif prev["answer"] == "잘못 골랐다":
        out["state"] = "wrong-choice-filtered"
    else:
        out["state"] = "answered-filtered"
    return out


def _why(item: dict) -> str:
    """리뷰어의 `why` — 줄바꿈 없는 빈 글 아닌 글이면 한 줄로 접은 글, 아니면 `-`."""
    raw = item.get("why")
    if not isinstance(raw, str) or "\n" in raw or not _one_line(raw):
        return "-"
    return _one_line(raw)


def _unidentified_id(question: str) -> str:
    return "unidentified:" + hashlib.sha1(question.encode("utf-8", UNWRITABLE)).hexdigest()[:12]


def _question_record(item: dict, ident: str, identified: bool, evidence: dict, lines: list,
                     quotes: list) -> dict:
    """남긴 질문의 레코드 — `lines` 는 확인된 근거 줄 번호(무효면 빈 목록), `quotes` 는 확인된 읽은 인용."""
    observation = []
    found = set()
    for n in lines:
        observation.append(evidence[n])
        found.add(io_.evidence_kind(evidence[n]))
    for quote in quotes:
        observation.append(io_.quote_line(quote))
    if quotes:
        found.add(io_.KIND_READ)
    return {"id": ident, "identified": identified, "state": "",
            "target_source": _text(item.get("target_source")),
            "target_id": _text(item.get("target_id")), "kind": _text(item.get("kind")),
            "weight": _text(item.get("weight")), "quote": _text(item.get("quote")),
            "label": _text(item.get("label")), "question": _text(item.get("question")).strip(),
            "evidence_lines": list(lines), "observation": observation,
            "read_quotes": list(quotes), "evidence_kinds": io_.ordered_kinds(found),
            "why": _why(item), "asked_before": "-", "changed_observation": "-"}


def _pick_rank(record: dict) -> tuple:
    """고르는 순서 — 무게, 같은 무게면 돌려 본 근거가 있는 질문이 앞(정렬이 안정이라 그다음은 들어온 순서)."""
    run_first = 0 if io_.KIND_RUN in record["evidence_kinds"] else 1
    return (WEIGHTS.get(record["weight"], len(WEIGHTS)), run_first)


def _quote_count(raw) -> int:
    """리뷰어가 적은 읽은 인용의 수 — 목록이면 그 길이, 목록이 아닌 값이 있으면 하나."""
    if isinstance(raw, list):
        return len(raw)
    return 1 if raw else 0


def _candidates(plan: dict, rd: str, ledger: Ledger, notices: List[str],
                reasons: List[str]) -> Optional[list]:
    """[(라벨, 호출 번호, 항목)] — 첫째 출력을 쓸 수 없으면 None(셀 수 없음).

    쓴 출력의 `none_reason` 이 빈 글 아닌 글이면 한 줄로 접어 `reasons` 에 더한다.
    """
    call = plan["call"]
    first, first_why, first_slot = _checked_output(_path(rd, OUT1), rd, 1)
    second, second_why, second_slot = _checked_output(_path(rd, OUT2), rd, 2)
    if call == "single":
        main, main_why, extra = second, _call_why("한 번에 넣은 호출", second_why, second_slot), None
    elif call in ("first-only", "split"):
        main, main_why, extra = first, _call_why("첫째 호출", first_why, first_slot), None
        if call == "split":
            extra = second
    else:
        main, main_why, extra = None, "준비 파일의 갈래를 모름(%s)" % (call or "-"), None
    if main is None:
        ledger.source_failed("intent-critic", main_why, primary=True)
        ledger.uncountable("intent-critic 후보", main_why)
        return None
    out = []
    for used in (main, extra):
        if used is not None and _one_line(used.get("none_reason")):
            reasons.append(_one_line(used.get("none_reason")))
    number = 1 if call != "single" else 2
    for i, item in enumerate(main["questions"], 1):
        out.append(("%s %d" % ("첫째" if number == 1 else "한 번", i), number, item))
    if call == "split" and extra is None:
        ledger.source_failed("intent-critic", _call_why("둘째 호출", second_why, second_slot),
                             primary=False)
        notices.append(SECOND_FAILED)
    elif extra is not None:
        for i, item in enumerate(extra["questions"], 1):
            out.append(("둘째 %d" % i, 2, item))
    return out


def _last_iteration(rd: str) -> Optional[str]:
    """마지막 반복의 번호 글자 — `review-i<N>.names` 가운데 N 이 가장 큰 것의 N. 없으면 None."""
    try:
        names = os.listdir(rd)
    except OSError:
        names = []
    best, best_number = -1, None
    for name in names:
        number = name[len(NAMES_PREFIX):-len(NAMES_SUFFIX)]
        if (name.startswith(NAMES_PREFIX) and name.endswith(NAMES_SUFFIX) and number.isdigit()
                and number.isascii() and int(number) > best):
            best, best_number = int(number), number
    return best_number


def _range_names(rd: str) -> Optional[set]:
    """마지막 반복의 `review-i<N>.names`(리뷰 범위가 바꾼 경로, 한 줄에 하나). 없으면 None."""
    number = _last_iteration(rd)
    text = _read(_path(rd, NAMES_PREFIX + number + NAMES_SUFFIX)) if number is not None else None
    if text is None:
        return None
    out = set()
    for line in text.split("\n"):
        if line:
            out.add(line)
    # 기준선이 degraded 면 review-diff.sh 가 목록을 일부러 비워 둔다 — 빈 목록은 「바뀐 것 없음」이 아니라 「모름」이다.
    return out or None


def _review_mode(rd: str) -> Optional[str]:
    """`_range_names` 와 같은 N 의 `review-i<N>.mode` — review-diff.sh 가 실제로 쓴 리뷰 범위 모드.

    글이 다섯 낱말 가운데 하나와 끝 줄바꿈까지 글자 그대로 같을 때만 그 낱말이다. 없음 · 읽지 못함 ·
    다른 N 뿐 · 그 밖의 글이면 None — 부르는 쪽이 `--review-mode` 인자로 간다.
    """
    number = _last_iteration(rd)
    if number is None:
        return None
    # newline="" — 줄 끝을 바꿔 읽지 않는다(`\r\n` · `\r` 이 `\n` 으로 읽혀 맞는 일이 없게). 64 글자면
    # 가장 긴 낱말보다 길어 더 긴 글은 맞지 않는다.
    try:
        with open(_path(rd, NAMES_PREFIX + number + MODE_SUFFIX), encoding="utf-8", errors="replace",
                  newline="") as fh:
            text = fh.read(64)
    except OSError:
        return None
    if not text.endswith("\n"):
        return None
    word = text[:-1]
    return word if word in REVIEW_MODES else None


def _range_identities(rd: str, tree_root: str) -> Optional[set]:
    """바뀐 파일 목록의 경로를 리뷰 트리 아래에서 푼 파일 정체(st_dev, st_ino) — 철자가 아니라 파일로 맞춘다."""
    names = _range_names(rd)
    if names is None or not tree_root:
        return None
    ids = set()
    for name in names:
        try:
            st = os.lstat(os.path.join(tree_root, name))
        except OSError:
            st = None
        if st is not None:
            ids.add((st.st_dev, st.st_ino))
    return ids


def _range_mark(path: str, ids: Optional[set], whole: bool) -> str:
    """added | not-added | unknown — 정체를 세우지 못하면 unknown 이다(표시 없이 두지 않는다).

    목록에 없다는 것은 목록이 범위 전체를 담을 때(whole)만 「더하지 않음」 이다. 아니면 unknown 이다.
    """
    if ids is None:
        return "unknown"
    try:
        st = os.lstat(path)
    except OSError:
        return "unknown"
    if (st.st_dev, st.st_ino) in ids:
        return "added"
    return "not-added" if whole else "unknown"


def _load_answered(plan: dict, rd: str, notices: List[str]) -> dict:
    cfg = _read_config(rd)
    if not plan["tree_root"] or cfg is None:
        notices.append("답 자리를 읽지 않았다 — 준비 파일에 리뷰 트리 경로가 없거나 설정을 읽지 못함")
        return {}
    answered, unreadable, why = ia.read_answered_under(plan["tree_root"], cfg["answers_dir"])
    if why:
        notices.append("답 자리를 읽지 않았다 — " + why)
    if unreadable:
        notices.append("읽지 못한 답 파일 %d" % unreadable)
    return answered


def _load_handed(rd: str, notices: List[str]) -> dict:
    """prepare 가 둔 넘겨받은 답의 복사본 → {열쇠: 항목}. 없으면 {}, 읽지 못하면 {} 와 공시 한 줄."""
    path = _path(rd, HANDED)
    if not os.path.lexists(path):
        return {}
    text = _read(path)
    try:
        data = yaml.safe_load(text) if text is not None else None
    except Exception:  # noqa: BLE001 — YAMLError 말고도 낸다. 어떤 실패든 읽지 못한 복사본이다
        data = None
    raw = data.get("entries") if isinstance(data, dict) else None
    handed: dict = {}
    ok = isinstance(raw, list)
    for item in raw if ok else []:
        # 항목의 꼴은 넘겨받은 파일을 읽을 때와 같은 검사로 본다(복사본엔 판 칸이 없다).
        entry = ia._handed_entry(item)
        if entry is None or entry["key"] in handed:
            ok = False
        else:
            handed[entry["key"]] = entry
    if not ok:
        notices.append(HANDED_UNREAD + ia.HANDED_BAD_SHAPE)
        return {}
    return handed


def _answer_rel(answers_dir: str, path: str) -> str:
    return answers_dir.rstrip("/") + "/" + os.path.basename(path)


def _judge(cands: list, plan: dict, rd: str, ledger: Ledger, counts: dict, answered: dict,
           handed: dict, ids: Optional[set], whole: bool) -> list:
    evidence = _evidence_lines(rd)
    answers_dir = (_read_config(rd) or {}).get("answers_dir", "")
    wide = plan["breadth"] != "narrow"
    first_ids = set()
    remaining: List[dict] = []
    decided: List[dict] = []
    for label, number, item in cands:
        if not isinstance(item, dict) or not _text(item.get("question")).strip():
            ledger.hold(label, "항목 파손")
            counts["broken"] += 1
            continue
        # 줄 인용은 하나라도 틀리면 묶음 전체가 무효다.
        # 읽은 인용은 넓은 리뷰에서만 리뷰 트리와 견준다.
        cited = _cited(item.get("evidence_lines"), evidence)
        raw_quotes = item.get("read_quotes")
        written = _quote_count(raw_quotes)
        quotes = io_.verify_quotes(plan["tree_root"], raw_quotes)[0] if wide else []
        if not cited and not written:
            ledger.suppressed(label, "근거 없어 거름")
            counts["evidence"] += 1
            continue
        if not cited and not wide:
            ledger.suppressed(label, "읽은 인용만 있어 거름")
            counts["read_only"] += 1
            continue
        if not cited and not quotes:
            ledger.suppressed(label, "인용이 그 파일에 없어 거름")
            counts["quote"] += 1
            continue
        lines = list(item["evidence_lines"]) if cited else []
        # 남긴 질문에서 근거로 받지 않은 것 — 확인 안 된(좁으면 보지 않은) 읽은 인용마다 하나,
        # 무효가 된 줄 인용 묶음 하나.
        dropped = written - len(quotes)
        if not cited and item.get("evidence_lines") not in (None, []):
            dropped += 1
        ident = _identity(item, plan)
        if ident is not None and number == 2 and plan["call"] == "split" and ident in first_ids:
            ledger.absorbed(label, ident)
            counts["absorbed"] += 1
            continue
        if ident is None:
            counts["unidentified"] += 1
            record = _question_record(item, _unidentified_id(_text(item.get("question")).strip()),
                                      False, evidence, lines, quotes)
        else:
            if number == 1:
                first_ids.add(ident)
            record = _question_record(item, ident, True, evidence, lines, quotes)
        # 넘겨받은 열쇠는 정체를 가르지 못한 질문에도 본다 — 답 폴더는 정체가 있을 때만.
        prior = _prior(item, ident, answered, handed, evidence, wide, plan["tree_root"])
        if prior is not None:
            record["asked_before"] = prior["asked_before"]
            record["changed_observation"] = prior["changed"]
        if prior is not None and prior["state"] is not None and prior["handed"] is not None:
            ledger.suppressed(label, "이미 답한 질문")
            counts["answered"] += 1
            entry = prior["handed"]
            record["state"] = prior["state"]
            record["previous_answer"] = entry["answer"]
            record["answer_file"] = entry["record"]
            record["handed"] = True
            record["deferred"] = prior["state"] == "deferred-filtered"
            if entry["id"] != record["id"]:
                record["identity_then"] = entry["id"]
            decided.append(record)
            continue
        if prior is not None and prior["state"] is not None:
            ledger.suppressed(label, "이미 답한 질문")
            counts["answered"] += 1
            record["state"] = prior["state"]
            record["previous_answer"] = answered[ident]["answer"]
            record["answer_file"] = _answer_rel(answers_dir, answered[ident]["path"])
            record["range_mark"] = _range_mark(answered[ident]["path"], ids, whole)
            decided.append(record)
            continue
        counts["cites_dropped"] += dropped
        record["label_in_run"] = label
        remaining.append(record)
    ordered = sorted(remaining, key=_pick_rank)
    for i, record in enumerate(ordered):
        label = record.pop("label_in_run")
        record["n"] = i + 1
        if i < CAP:
            ledger.accept(label)
            record["state"] = "ask"
        else:
            ledger.suppressed(label, "상한 넘어 남김")
            counts["over_cap"] += 1
            record["state"] = "over-cap"
    return ordered + decided


def cmd_filter(args) -> int:
    rd = args.rd
    ledger = Ledger(items="open")
    notices: List[str] = []
    counts = {"evidence": 0, "quote": 0, "read_only": 0, "answered": 0, "over_cap": 0,
              "unidentified": 0, "broken": 0, "absorbed": 0, "cites_dropped": 0}
    plan = _read_plan(rd)
    questions: List[dict] = []
    none_reasons: List[str] = []
    if plan is None:
        status, call = "uncountable", "-"
        ledger.uncountable("intent-critic 후보", "준비 파일(%s)이 없음" % PLAN)
    elif plan["call"] == "none":
        status, call = "no-evidence", "none"
    else:
        call = plan["call"]
        if plan["breadth"] != "narrow" and not os.path.isdir(plan["tree_root"] or ""):
            cands = None
            notices.append(NOTICE_NO_TREE)
            ledger.uncountable("intent-critic 후보", NOTICE_NO_TREE)
        else:
            cands = _candidates(plan, rd, ledger, notices, none_reasons)
        if cands is None:
            status = "uncountable"
        else:
            status = "ran"
            answered = _load_answered(plan, rd, notices)
            handed = _load_handed(rd, notices)
            ids = _range_identities(rd, plan["tree_root"])
            # review-diff.sh 가 남긴 모드가 이긴다 — 인자는 그 파일이 없을 때의 대체값이다.
            whole = (_review_mode(rd) or args.review_mode) in WHOLE_SCOPE_MODES
            questions = _judge(cands, plan, rd, ledger, counts, answered, handed, ids, whole)
            # 범위 표시는 답 폴더의 답으로 거른 것에만 단다 — 넘겨받은 항목엔 없다.
            from_folder = 0
            for record in questions:
                if record.get("state") in FILTERED_STATES and not record.get("handed"):
                    from_folder += 1
            if from_folder and ids is None:
                notices.append(NAMES_MISSING)
            elif not whole:
                partial = False
                for record in questions:
                    if record.get("range_mark") == "unknown":
                        partial = True
                if partial:
                    notices.append(NAMES_PARTIAL)
    for key, template in COUNT_NOTICES:
        if counts[key]:
            notices.append(template % counts[key])
    report = ledger.report()
    for reason in report["reasons"]:
        notices.append("intent-critic 처분 — " + reason)
    asked = 0
    for record in questions:
        if record["state"] == "ask":
            asked += 1
    _write_questions(rd, {"status": status, "call": call, "counts": counts,
                          "disposition": disposition_report(report, ledger.held_by_class()),
                          "notices": notices, "commit": "-", "commit_line": "",
                          "none_reason": " / ".join(none_reasons) if none_reasons else "-",
                          "questions": questions})
    _emit(notices)
    print("intent-ask: %d" % asked)
    return 0


# ---------------------------------------------------------------- record

def _header_parts(line: str) -> tuple:
    """답 머리 꼴 줄 → (번호 | None, 정체 | None, 고른 것 | None).

    고른 것은 `PICK_SEP` 를 오른쪽에서 갈라 얻는다(옛 `=== id: ` 꼴도). 번호와 정체는 `=== n: ` 꼴이고
    `ID_SEP` 앞이 ASCII 숫자일 때만 읽힌다.
    """
    body, sep, pick = line.rpartition(PICK_SEP)
    if sep:
        pick = pick.rstrip()
    else:
        body, pick = line, None
    number, ident = None, None
    if body.startswith(HEADER):
        digits, sep, rest = body[len(HEADER):].partition(ID_SEP)
        if sep and digits and set(digits) <= DIGITS and len(digits) <= 9:
            number, ident = int(digits), rest
    return number, ident, pick


def parse_answer_input(text: str, known: dict) -> dict:
    """`=== n: <번호> · id: <정체> · pick: <답|typed>` 머리로 가른 답들. `known` 은 묻는 질문의 {번호: 정체}.

    → {"entries": [{"n", "id", "pick", "lines"}], "orphan": 첫 머리 앞의 빈 줄 아닌 줄 수,
       "mismatched": [(번호 | None, 읽힌 고른 답 | None)], "duplicates": 같은 번호의 머리가 더 나온 수}.
    답 머리 꼴 줄은 늘 지금 답을 끝낸다. 번호 · 정체가 맞는 그 번호의 첫 머리만 답이고, 고른 것이 라벨 · typed
    가 아니면 `pick` 이 None 인 답이다(아래 글은 싣지 않는다). 맞지 않는 머리 · 더 나온 머리와 그 아래 글은
    어디에도 싣지 않는다. 머리 꼴이 아닌 줄(`===` 로 시작하는 다른 줄 포함)은 지금 답의 원문이다.
    """
    picks = ia.ANSWERS + (TYPED,)
    entries: List[dict] = []
    mismatched: List[tuple] = []
    taken: set = set()
    duplicates = 0
    orphan = 0
    started = False
    current: Optional[dict] = None
    for line in text.split("\n"):
        bare = line.rstrip("\r")
        if bare.startswith(HEADER_SHAPES):
            started = True
            current = None
            number, ident, pick = _header_parts(bare)
            if number is not None and number in known and ident == known[number]:
                if number in taken:
                    duplicates += 1
                else:
                    taken.add(number)
                    entry = {"n": number, "id": ident, "pick": pick if pick in picks else None,
                             "lines": []}
                    entries.append(entry)
                    if entry["pick"] is not None:
                        current = entry
            else:
                mismatched.append((number, pick if pick in picks else None))
        elif current is not None:
            current["lines"].append(line)
        elif not started and bare.strip():
            orphan += 1
    return {"entries": entries, "orphan": orphan, "mismatched": mismatched,
            "duplicates": duplicates}


def _read_pick(entry: dict) -> tuple:
    """(답, 답 원문)."""
    raw = "\n".join(entry["lines"]).strip("\n")
    if entry["pick"] != TYPED:
        return entry["pick"], raw or entry["pick"]
    answer = "지금은 모르겠다"
    head = raw.lstrip()
    for candidate in ia.ANSWERS:
        if head.startswith(candidate) and answer == "지금은 모르겠다":
            answer = candidate
    return answer, raw


def _git_out(repo: str, *args: str) -> Optional[str]:
    try:
        res = subprocess.run(["git", "-C", repo] + list(args), capture_output=True)
    except OSError:
        return None
    if res.returncode != 0:
        return None
    return res.stdout.decode("utf-8", "replace")


def _resolve_commit(repo: str, rev: str) -> str:
    """rev 를 커밋 해시(40자 16진)로 푼다 — `-` · `-` 로 시작하는 글 · 못 푸는 rev 는 `-`."""
    if rev == "-" or rev.startswith("-"):
        return "-"
    out = _git_out(repo, "rev-parse", "--verify", "--quiet", rev + "^{commit}")
    sha = (out or "").strip()
    if len(sha) == 40 and set(sha) <= set("0123456789abcdef"):
        return sha
    return "-"


def _review_target(repo: str, answers_dir: str) -> str:
    """`tree <HEAD 트리 목록에서 답 자리를 뺀 것의 sha1 앞 12자> · dirty <yes|no>`."""
    prefix = answers_dir.rstrip("/") + "/"
    listing = _git_out(repo, "ls-tree", "-r", "HEAD")
    kept = []
    for line in (listing or "").splitlines():
        if not line.split("\t", 1)[-1].startswith(prefix):
            kept.append(line)
    tree = hashlib.sha1("\n".join(kept).encode("utf-8")).hexdigest()[:12]
    if listing is None:
        tree = "unknown"
    status = _git_out(repo, "status", "--porcelain")
    dirty = False
    for line in (status or "").splitlines():
        if line.strip() and not line[3:].strip('"').startswith(prefix):
            dirty = True
    return "tree %s · dirty %s" % (tree, "yes" if dirty else "no")


def _stamp(moment: datetime.datetime) -> str:
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def _unique_name(ident: str, now: datetime.datetime, taken: set, directory: str) -> tuple:
    step = 0
    at = _stamp(now)
    name = ia.answer_filename(ident, at)
    while name in taken or os.path.lexists(os.path.join(directory, name)):
        step += 1
        at = _stamp(now + datetime.timedelta(seconds=step))
        name = ia.answer_filename(ident, at)
    taken.add(name)
    return name, at


def _one_line(value, limit: int = 0) -> str:
    """공시 줄에 싣는 글 — 줄바꿈 · 제어 글자를 빈칸으로 접어 한 줄로 만들고, limit 가 있으면 그 길이에서 자른다.

    리뷰어 출력에서 온 글이 스크립트 출력의 줄이나 결과 절의 머리 줄을 흉내 내지 못한다.
    """
    chars = []
    for ch in _text(value):
        # 짝 없는 surrogate 는 지우지 않는다 — 쓰는 자리가 `\\ud800` 꼴로 남긴다.
        chars.append(ch if ch.isprintable() or "\ud800" <= ch <= "\udfff" else " ")
    text = " ".join("".join(chars).split())
    if limit and len(text) > limit:
        text = text[:limit] + "…"
    return text


def _failed_notices(failed: List[tuple]) -> List[str]:
    """기록되지 않은 답 [(질문, 고른 답 | None, 사유)] 의 공시 — 사유마다 수 한 줄, 그 아래 질문마다 정체 ·
    고른 답 · 질문 글 한 줄. 그 질문에 표지를 단다."""
    reasons: List[str] = []
    counts: dict = {}
    for record, picked, reason in failed:
        record["record_failed"] = True
        if picked:
            record["failed_answer"] = picked
        record["failure"] = reason
        if reason not in counts:
            reasons.append(reason)
            counts[reason] = 0
        counts[reason] += 1
    lines = []
    for reason in reasons:
        lines.append(RECORD_FAILED % (counts[reason], reason))
        for record, answer, why in failed:
            if why == reason:
                lines.append(RECORD_FAILED_ITEM % (_one_line(record.get("id")),
                                                   answer or PICK_UNREAD,
                                                   _one_line(record.get("question"), SNIPPET)))
    return lines


def _save_record(rd: str, data: Optional[dict], notices: List[str]) -> None:
    """record 의 공시 · 표지를 거르기 결과에 남겨 render 가 result.md 에 보이게 한다."""
    if data is None:
        return
    data["record_notices"] = list(data.get("record_notices") or []) + notices
    _write_questions(rd, data)


def _keep_typed(record: dict, entry: dict) -> None:
    """직접 쓴 답이면 그 원문 줄들을 질문에 남긴다 — 기록에 성공했든 실패했든 돌려주는 꼴의 `answer_text`."""
    if entry["pick"] == TYPED:
        raw = _read_pick(entry)[1]
        if raw:
            record["answer_text"] = raw.split("\n")


def _answers_in_input(parsed: dict, by_n: dict) -> tuple:
    """입력에 답이 있던 질문 — (받은 답 [(질문, 답 항목)], 제 사유로 기록하지 못할 답 [(질문, 고른 답 | None, 사유)]).

    받은 답 · 고른 것을 읽지 못한 머리(`답을 읽지 못함`) · 번호만 맞은 머리(`정체가 맞지 않는 답 머리` — 같은
    번호에 받은 머리가 따로 있으면 그것이 이긴다)가 든다.
    """
    good: List[tuple] = []
    own: List[tuple] = []
    hit: set = set()
    for entry in parsed["entries"]:
        record = by_n[entry["n"]]
        hit.add(entry["n"])
        if entry["pick"] is None:
            own.append((record, None, PICK_UNREAD))
        else:
            good.append((record, entry))
            _keep_typed(record, entry)
    for number, pick in parsed["mismatched"]:
        if number in by_n and number not in hit:
            hit.add(number)
            own.append((by_n[number], pick if pick in ia.ANSWERS else None, MISMATCH_FAILURE))
    return good, own


def _input_notices(parsed: dict, known: dict, asked: List[dict], text: Optional[str]) -> List[str]:
    """답 입력을 읽은 공시 — 머리 없음 · 머리 앞 글 · 정체가 맞지 않는 머리(4a) · 더 나온 같은 번호 머리."""
    notices = []
    if not parsed["entries"] and known and text is not None and text.strip():
        notices.append(NO_HEADER % len(asked))
    if parsed["orphan"]:
        notices.append(ORPHAN % parsed["orphan"])
    if parsed["mismatched"]:
        notices.append(MISMATCHED % len(parsed["mismatched"]))
    if parsed["duplicates"]:
        notices.append(DUPLICATE_HEADERS % parsed["duplicates"])
    return notices


def _record(args) -> tuple:
    """(공시 줄들, 기록한 답 파일 수)."""
    switches = _switches_on()
    plan = _read_plan(args.rd)
    if plan is not None and plan["mode"] == "range":
        if switches:
            return [KILL_RECORD % _kill_text(switches)], 0
        return [], 0
    data = _read_questions(args.rd)
    if data is not None:
        data["record_ran"] = True   # render 가 「묻기 전에 끝남」 과 「답하지 않음」 을 가른다
    cfg = _read_config(args.rd)
    text = _read(args.answers)
    known: dict = {}
    by_n: dict = {}
    asked: List[dict] = []
    for record in (data or {}).get("questions") or []:
        if isinstance(record, dict) and record.get("state") == "ask":
            asked.append(record)
            if type(record.get("n")) is int:
                known[record["n"]] = record.get("id")
                by_n[record["n"]] = record
    parsed = {"entries": [], "orphan": 0, "mismatched": [], "duplicates": 0}
    if data is not None and text is not None:
        parsed = parse_answer_input(text, known)
    good, own = _answers_in_input(parsed, by_n)
    notices = _input_notices(parsed, known, asked, text)

    # 기록하지 않는 갈래 — 입력에 답이 있던 질문에만 그 갈래의 사유로 실패 표지를 단다. 답 입력 파일 자체를
    # 읽지 못하면 답이 있었는지 알 수 없어 묻는 질문 모두에 단다.
    blocked = None
    lead = None
    if switches:
        blocked = KILL_FAILURE % _kill_names(switches)
        lead = KILL_RECORD % _kill_text(switches)
    elif plan is None:
        blocked = "준비 파일(%s)을 읽지 못함" % PLAN
    elif data is None or cfg is None or text is None:
        blocked = "거르기 결과 · 설정 · 답 입력 중 읽지 못한 것이 있다"
    if blocked:
        failed = []
        if text is None:
            for record in asked:
                failed.append((record, None, blocked))
        for record, entry in good:
            failed.append((record, _read_pick(entry)[0], blocked))
        for record, picked, _why in own:
            failed.append((record, picked, blocked))
        notices = [lead or "답을 기록하지 못했다 — " + blocked] + notices + _failed_notices(failed)
        _save_record(args.rd, data, notices)
        return notices, 0

    if not good:
        notices += _failed_notices(own)
        _save_record(args.rd, data, notices)
        return notices, 0
    answers_dir = cfg["answers_dir"]
    target = _review_target(args.repo, answers_dir)
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    directory = os.path.join(args.repo, answers_dir)
    taken: set = set()
    files = []
    pairs = []
    for record, entry in good:
        answer, raw = _read_pick(entry)
        name, at = _unique_name(record["id"], now, taken, directory)
        files.append((name, ia.render_answer_file(
            record["id"], record.get("question", ""), record.get("quote", ""),
            record.get("label", ""), record.get("observation") or [], answer, raw, target, at)))
        pairs.append((record, answer))
    paths, write_error = ia.write_answer_files(args.repo, answers_dir, files)
    # 답 파일이 생긴 질문만 답함이다. 파일을 쓰지 못한 질문은 묻는 상태로 남기고 수와 사유를 공시한다.
    failed = []
    for i, (record, answer) in enumerate(pairs):
        if i < len(paths):
            record["state"] = "answered"
            record["answer"] = answer
            record["file"] = paths[i]
        else:
            failed.append((record, answer, write_error or "답 파일이 없다"))
    notices += _failed_notices(failed + own)
    data["record_notices"] = list(data.get("record_notices") or []) + notices
    if paths:
        sha, commit_error = ia.commit_answer_files(args.repo, paths,
                                                   COMMIT_MESSAGE % len(paths))
        if sha:
            data["commit"] = sha
            line = "답 파일 %d개를 커밋했다(%s)" % (len(paths), sha)
        else:
            data["commit"] = "failed — " + commit_error
            line = "답 파일을 커밋하지 못했다 — %s(파일은 남겼다)" % commit_error
    else:
        data["commit"] = "failed — " + (write_error or "답 파일이 없다")
        line = "답 파일을 쓰지 못했다 — %s" % (write_error or "답 파일이 없다")
    data["commit_line"] = line
    notices.append(line)
    _write_questions(args.rd, data)
    return notices, len(paths)


def cmd_record(args) -> int:
    notices, count = _record(args)
    _emit(notices)
    print("record: %d" % count)
    return 0


# ---------------------------------------------------------------- render

def _cell(value) -> str:
    return _text(value).replace("\n", " ").replace("|", "\\|")


def _question_state(record: dict, mode: str, record_ran: bool) -> Optional[str]:
    """질문 레코드 하나의 돌려주는 꼴 상태 — 거른 상태(이미 답해 거름 등)는 None."""
    state = record.get("state")
    if state == "answered":
        return QUESTION_STATES[0]
    if state == "over-cap":
        return QUESTION_STATES[4]
    if state != "ask":
        return None
    if mode == "range":
        return QUESTION_STATES[3]
    if record.get("record_failed"):
        return QUESTION_STATES[1]
    if record_ran:
        return QUESTION_STATES[2]
    return QUESTION_STATES[3]


def _outcome(plan: Optional[dict], data: Optional[dict], mode: str) -> dict:
    """키 `status` · `reason` · `reason_text` · `outcome` · `result_line` · `notices`."""
    notices = []
    if data is not None:
        notices = list(data.get("notices") or []) + list(data.get("record_notices") or [])
    out = {"status": "ran", "reason": "-", "reason_text": "-", "outcome": "-",
           "result_line": "", "notices": notices}
    if plan is None:
        out["notices"] = ["준비 파일(%s)을 읽지 못함" % PLAN] + notices
    elif plan["call"] == "none":
        out.update(status="skipped", reason="no-evidence", reason_text="근거 없음",
                   result_line=NO_EVIDENCE, notices=[])
        return out
    elif data is None:
        out["notices"] = ["거르기 결과(%s)가 없음" % QUESTIONS]
    if plan is None or data is None or data.get("status") == "uncountable":
        first = _one_line(out["notices"][0]) if out["notices"] else ""
        out.update(status="uncountable", reason_text=first or "-", result_line=UNREADABLE)
        return out
    record_ran = bool(data.get("record_ran"))
    asked = answered = wrong = failed = unanswered = not_asked = 0
    for record in data["questions"]:
        if record.get("state") in ("ask", "answered"):
            asked += 1
        state = _question_state(record, mode, record_ran)
        if state == "답함":
            answered += 1
            if record.get("answer") == "잘못 골랐다":
                wrong += 1
        elif state == "답 기록 실패":
            failed += 1
        elif state == "답하지 않음":
            unanswered += 1   # 묻고도 답을 받지 못한 질문
        elif state == "묻지 않음":
            not_asked += 1
    counts = data.get("counts") or {}
    filtered = 0
    for key in FILTERED_KEYS:
        if type(counts.get(key)) is int:
            filtered += counts[key]
    if asked == 0:
        if filtered > 0 and not counts.get("answered"):
            if plan["breadth"] != "narrow":
                out.update(outcome="all-filtered", result_line=ALL_FILTERED % filtered)
            else:
                out.update(outcome="no-evidence", result_line=NO_EVIDENCE)
        else:
            out.update(outcome="none", result_line=NO_QUESTION)
        return out
    out["outcome"] = "questions"
    if mode == "range":
        out["result_line"] = NOT_ASKED_RANGE % not_asked
        return out
    if not record_ran:
        out["result_line"] = NOT_ASKED_EARLY % not_asked
        return out
    line = "intent-critic — 질문 %d개를 물었다 · 답 %d개(잘못 골랐다 %d개)" % (
        answered + failed + unanswered, answered, wrong)
    if unanswered:
        line += UNANSWERED % unanswered
    out["result_line"] = line
    return out


def _rows(data: Optional[dict], mode: str) -> List[dict]:
    """질문 칸 — 키는 `QUESTION_KEYS`. 거른 상태의 레코드는 행이 없다."""
    rows = []
    record_ran = bool((data or {}).get("record_ran"))
    for record in (data or {}).get("questions") or []:
        state = _question_state(record, mode, record_ran)
        if state is not None:
            rows.append(_row(record, state, mode))
    return rows


def _row(record: dict, state: str, mode: str) -> dict:
    """질문 칸 하나 — 키는 `QUESTION_KEYS`."""
    answer = "-"
    if state == "답함":
        answer = record.get("answer") or "-"
    elif state == "답 기록 실패":
        answer = record.get("failed_answer") or "-"
    # 근거의 종류가 없는 레코드(R1 꼴)는 `-`.
    kinds = record.get("evidence_kinds")
    evidence = KIND_SEP.join(map(_text, kinds)) if isinstance(kinds, list) and kinds else "-"
    lines = record.get("answer_text")
    observation = record.get("observation")
    changed = record.get("changed_observation")
    return {"n": record.get("n"), "id": _text(record.get("id")), "state": state,
            "answer": answer, "answer_text": lines if isinstance(lines, list) and lines else "-",
            "wrong_choice": answer == "잘못 골랐다",
            "failure": (record.get("failure") or "-") if state == "답 기록 실패" else "-",
            "file": "-" if mode == "range" else (record.get("file") or "-"),
            "evidence": evidence, "question": record.get("question", ""),
            "target_source": record.get("target_source", ""),
            "target_id": record.get("target_id", ""), "label": record.get("label", ""),
            "quote": record.get("quote", ""),
            "observation": observation if isinstance(observation, list) else [],
            # R5 꼴의 레코드(이 칸들이 없다)는 `-`.
            "why": record.get("why") or "-", "asked_before": record.get("asked_before") or "-",
            "changed_observation": changed if isinstance(changed, list) and changed else "-"}


def _teams_record(rd: str) -> tuple:
    """(돌려주는 꼴의 other_teams, 겹침 줄들, 확인 못 함 줄들, 겹침 수) — `other-teams.md` 를 읽기만 한다.

    줄은 `ot.summary`(팀 지도 머리 앞까지)로만 얻는다 — 다른 브랜치의 본문이 목록 줄을 흉내 내지 못한다.
    겹침 수는 「겹침 확인 못 함」 이면 `-`(모름), 「겹침 없음」 이면 0, 그 밖에는 줄 수. 기록이 없으면 줄이 None.
    """
    text = _read(_path(rd, OTHER_TEAMS))
    if text is None:
        return "-", None, None, "-"
    overlap, unverified = ot.summary(text)
    if not overlap or ot.OVERLAP_UNKNOWN in overlap:
        count = "-"
    else:
        count = len(overlap) - overlap.count(ot.NO_OVERLAP)
    return OTHER_TEAMS, overlap or [TEAMS_UNREAD], unverified or [TEAMS_UNREAD], count


def _filtered_mark(record: dict) -> str:
    """걸러진 목록 줄의 표시 — 넘겨받은 항목은 「넘겨받은 답」[ · 미뤄 둔 의심][ · 정체가 다름 — …](범위 표시
    없음), 답 폴더의 답은 범위 표시."""
    if not record.get("handed"):
        return RANGE_MARKS.get(record.get("range_mark"), "")
    mark = KIND_SEP + HANDED_MARK
    if record.get("deferred"):
        mark += KIND_SEP + DEFERRED_MARK
    if record.get("identity_then"):
        mark += KIND_SEP + IDENTITY_DIFFERS % (_cell(record["identity_then"]),
                                               _cell(record.get("id")))
    return mark


def _section(line: str, notices: List[str], data: Optional[dict], rows: List[dict],
             teams: tuple = (None, None)) -> str:
    """결과 절. `teams` 는 `_teams_record` 의 (겹침 줄들, 확인 못 함 줄들) — None 이면 기록 없음."""
    out = ["", SECTION, "", SECTION_LEAD, "", "- " + line]
    for notice in notices:
        out.append("- " + notice)
    if data and data.get("commit_line"):
        out.append("- " + data["commit_line"])
    if rows:
        out += ["", TABLE_HEAD, "|---|---|---|---|---|---|"]
    for row in rows:
        out.append("| %s | %s | %s | %s | %s | %s |" % (
            _cell(row["id"]), row["state"], _cell(row["evidence"]), _cell(row["answer"]),
            _cell(row["file"]), _cell(row["question"])))
    overlap, unverified = teams
    if overlap is None or unverified is None:
        out += ["", NO_TEAMS_RECORD]
    else:
        out += ["", OVERLAP_HEAD] + overlap + ["", UNVERIFIED_HEAD] + unverified
    over = []
    wrong = []
    filtered = []
    for record in (data or {}).get("questions") or []:
        item = "- %s — %s" % (_text(record.get("id")), _cell(record.get("question")))
        if record.get("state") == "over-cap":
            over.append(item)
        elif record.get("state") == "wrong-choice-filtered" and not record.get("handed"):
            wrong.append(item)
        if record.get("state") in FILTERED_STATES:
            filtered.append("- %s · %s · %s%s — %s" % (
                _cell(record.get("id")), _cell(record.get("previous_answer")),
                _cell(record.get("answer_file")), _filtered_mark(record),
                _cell(record.get("question"))))
    out += ["", "상한 넘어 남김:"] + (over or ["- 없음"])
    if filtered:
        out += ["", "이미 답한 질문이라 거른 질문:"] + filtered
    if wrong:
        out += ["", "이미 「잘못 골랐다」 답이 있어 거른 질문:"] + wrong
    return "\n".join(out) + "\n"


def cmd_render(args) -> int:
    rd = args.rd
    result_path = _path(rd, RESULT)
    # 「이미 돌았나」는 이 단계가 세션 폴더에 남긴 표지로만 정한다 — result.md 글(앞 절에 옮겨 적힌
    # 리뷰 트리 글이 섞일 수 있다)을 훑어 정하지 않는다.
    marker = _path(rd, RENDERED)
    if os.path.exists(marker):
        print(ALREADY)
        return 0
    existing = _read(result_path) or ""
    plan = _read_plan(rd)
    data = _read_questions(rd) if plan is None or plan["call"] != "none" else None
    outcome = _outcome(plan, data, args.mode)
    line, notices = outcome["result_line"], outcome["notices"]
    rows = _rows(data, args.mode)
    lead = "" if not existing or existing.endswith("\n") else "\n"
    shown = list(notices)
    if plan is not None:
        # prepare 의 공시가 앞에 선다. filter · record 가 다시 낸 줄은 한 번만 보인다.
        front = []
        for prepared in _prepare_notices(rd):
            if prepared not in notices and prepared not in front:
                front.append(prepared)
        shown = front + shown
    other_teams, overlap, unverified, overlaps = _teams_record(rd)
    _append(result_path, lead + _section(line, shown, data, rows, (overlap, unverified)))
    commit = "-" if args.mode == "range" else _text((data or {}).get("commit") or "-")
    breadth = "-" if plan is None else plan["breadth"]
    # 이미 답해 거른 수 — 거르기가 돈 실행에서만 센다. 건너뜀 · 셀 수 없음은 `-`.
    answered_filtered = ((data.get("counts") or {}).get("answered")
                         if outcome["status"] == "ran" and data is not None else None)
    head = {"status": outcome["status"], "reason": outcome["reason"],
            "reason_text": outcome["reason_text"], "outcome": outcome["outcome"],
            "result_line": line, "none_reason": (data or {}).get("none_reason") or "-",
            "mode": args.mode, "reviewed_head": "-" if plan is None else plan["reviewed_head"],
            "reviewed_base": "-" if plan is None else plan["reviewed_base"],
            "commit": commit, "breadth": breadth, "other_teams": other_teams,
            "overlaps": overlaps, "answered_filtered": answered_filtered}
    _write_return(rd, head, rows)
    _write(marker, line + "\n")
    _emit(notices)
    print(line)
    return 0


# ---------------------------------------------------------------- 인자

def _parser() -> argparse.ArgumentParser:
    top = argparse.ArgumentParser(
        prog="intent_critic.py",
        description="intent-critic 단계 — 판정 밖 질문의 입구 · 조립 · 거름 · 기록 · 렌더.")
    sub = top.add_subparsers(dest="sub", metavar="<sub>")
    sub.required = True

    p = sub.add_parser("gate", help="돌지 건너뛸지 정한다",
                       description="kill switch 를 먼저 본다. final 이면 「intent-gate: run」, "
                                   "건너뛰면 공시 한 줄과 intent-return.md 를 쓴다. rc 0 · 잘못된 호출 2.")
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--path", required=True, choices=("final",) + tuple(GATE_SKIPS),
                   help="이 실행이 지나온 길 — final · aborted · trivia · scope-empty · tree-failed")
    p.add_argument("--mode", choices=("pr", "range"), default=None,
                   help="돌려주는 꼴의 mode 칸(모르면 생략 → -)")
    p.set_defaults(func=cmd_gate)

    p = sub.add_parser("config", help="docs 답 자리 · 입력 상한을 읽는다",
                       description="환경 변수 %s · %s · %s · %s 를 읽어 intent-config.txt 여덟 줄(네 "
                                   "값과 저마다의 출처)을 쓴다. 리뷰 "
                                   "트리의 .claude/settings.json · settings.local.json 이 base 와 그 키가 "
                                   "다르면 기본값(default-settings-changed). --base - 는 base 를 "
                                   "모름 — 그때 리뷰 트리 설정에 그 키가 있으면 바뀐 것으로 본다."
                                   % (DIR_ENV, MAX_ENV, OTHER_MAX_ENV, MARKERS_ENV))
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--repo", required=True, help="리포 루트(base 쪽 설정을 git show 로 읽는다)")
    p.add_argument("--base", required=True, help="기준 rev, 모르면 -")
    p.add_argument("--project-dir", required=True, help="리뷰 트리(리뷰 쪽 설정을 읽는다)")
    p.set_defaults(func=cmd_config)

    p = sub.add_parser("prepare", help="근거 · 원문 · 로드맵 · 의도 · 의심 · 답을 조립한다",
                       description="intent-config.txt 가 먼저 있어야 한다. 리뷰의 넓이를 정하고 다른 "
                                   "팀 기록(%s) · scope 칸(%s)을 쓴다. 공시 줄들 뒤 "
                                   "「intent-call: <none|first-only|split|single>」. rc 0 · 입력 못 읽음 4. "
                                   "kill switch 가 켜져 있으면 아무것도 조립하지 않고 gate 와 같은 꺼짐 "
                                   "줄 · 돌려주는 꼴만 낸다(rc 0)."
                                   % (OTHER_TEAMS, SCOPE))
    p.add_argument("--rd", required=True, help="qg 세션 폴더(e2e-record.md · differential.yaml · "
                                               "intent.md 를 읽는다)")
    p.add_argument("--repo", required=True, help="리포 루트(원문 · 로드맵을 git 으로 읽는다)")
    p.add_argument("--tree-root", required=True,
                   help="리뷰 트리 루트 — 이곳의 docs 답 자리 답 파일을 읽는다")
    p.add_argument("--mode", required=True, choices=("pr", "range"))
    p.add_argument("--head", required=True, help="부른 쪽 원문을 읽을 rev")
    p.add_argument("--review-commit", required=True, help="리뷰한 커밋(설계문서 링크를 읽을 rev)")
    p.add_argument("--specs-json", required=True, help="P3 의 JSON 한 줄이 든 파일")
    p.add_argument("--origin", default=None, help="부른 쪽이 넘긴 원문(리포 상대 경로)")
    p.add_argument("--base", default="-",
                   help="리뷰 범위의 기준 rev — intent-scope.md 의 커밋 제목(base..review-commit)을 "
                        "읽는다. 모르면 -")
    p.add_argument("--answered", default=None,
                   help="지휘자가 넘긴 「이미 답한 것」 파일(절대 경로) — intent-critic 단계에만 쓴다")
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("slots", help="호출 하나의 칸 사본을 쓴다",
                       description="세션 폴더의 원본(review-i1.diff · %s · %s · %s · %s · %s · %s(k=2 만) · "
                                   "%s)마다 원본 끝에 `qg-slot-end: <16 hex>` 줄을 붙인 사본 "
                                   "intent-slot-<k>-<칸>.md 를 쓰고 「<칸>\\t<경로>」 줄을 낸다 — 칸마다 · "
                                   "호출마다 새 값. 원본은 그대로다. 둘째 호출의 사본은 doubts-append 뒤에 "
                                   "만든다. rc 0 · 원본을 읽지 못했거나 쓰지 못함 4(이 호출의 사본을 "
                                   "모두 지운다)."
                                   % (SCOPE, EVIDENCE, ORIGIN, ROADMAP, INTENT, DOUBTS, ANSWERED))
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--call", required=True, type=int, choices=(1, 2),
                   help="1 첫째 호출 · 2 둘째 호출 또는 한 번에 넣은 호출")
    p.set_defaults(func=cmd_slots)

    p = sub.add_parser("check-output", help="리뷰어 응답을 읽을 수 있나 본다",
                       description="먼저 응답 파일과 같은 폴더의 그 호출 칸 사본(intent-slot-<k>-*.md)의 "
                                   "끝 값이 응답에 모두 있는지 본다 — 아니면 「unreadable: 끝 값 없음」 "
                                   "(응답에 QG_INPUT_UNREADABLE: 로 시작하는 줄이 있으면 「unreadable: 읽지 "
                                   "못함」) rc 3. 그다음 qg-intent-critic 펜스 하나 + questions 목록이면 "
                                   "「readable」 rc 0, 아니면 「unreadable: <사유>」 rc 3.")
    p.add_argument("file", help="리뷰어 응답 파일")
    p.add_argument("--call", required=True, type=int, choices=(1, 2),
                   help="그 응답의 호출 — 1 첫째 · 2 둘째 또는 한 번에 넣은 호출")
    p.set_defaults(func=cmd_check_output)

    p = sub.add_parser("doubts-append", help="첫째 호출의 후보를 의심 파일 끝에 덧붙인다",
                       description="intent-critic-1.txt 의 후보를 intent-doubts.md 끝 「%s」 아래에 "
                                   "한 번만 덧붙인다. 마지막 줄 「doubts-append: <n>」." % FIRST_CANDIDATES)
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.set_defaults(func=cmd_doubts_append)

    p = sub.add_parser("filter", help="후보를 거르고 상한을 둔다",
                       description="intent-plan.txt 의 call 로 응답을 고른다(first-only=1 · single=2 · "
                                   "split=1 과 2 의 합). 응답마다 그 호출의 칸 사본 끝 값과 먼저 견준다 — "
                                   "맞지 않으면 그 응답을 쓰지 않는다. 근거 · 정체 · 이미 답함 · 상한 순으로 거르고 "
                                   "intent-questions.yaml 을 쓴다. 공시 줄들 뒤 「intent-ask: <k>」. rc 0.")
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--review-mode", default="-",
                   help="마지막 반복의 리뷰 diff 모드(review-diff.sh 의 mode: 값) — 대체값이다. 세션 "
                        "폴더에 바뀐 파일 목록과 같은 N 의 review-i<N>.mode 가 있고 그 글이 다섯 모드 "
                        "가운데 하나면 그 값이 이긴다. %s 이면 바뀐 파일 "
                        "목록이 범위 전체다. paths · 모름(-) · 그 밖의 값이면 목록에 없는 답 파일을 "
                        "「더하지 않음」 이 아니라 「모름」 으로 표시한다." % " · ".join(WHOLE_SCOPE_MODES))
    p.set_defaults(func=cmd_filter)

    p = sub.add_parser("record", help="답 파일을 docs 답 자리에 쓰고 그 파일만 커밋한다",
                       description="입력 꼴: 「%s<번호>%s<정체>%s<의도다|잘못 골랐다|지금은 모르겠다|typed>」 "
                                   "머리 줄 뒤 다음 머리 전까지가 답 원문. 번호 · 정체가 묻는 질문과 맞지 "
                                   "않는 머리 · 같은 번호로 더 나온 머리와 그 아래 글은 어디에도 싣지 "
                                   "않는다. 범위 모드면 아무것도 쓰지 않는다. kill switch 가 켜져 있으면 "
                                   "답 파일을 쓰지 않고 커밋하지 않는다. 마지막 줄 「record: <n>」. rc 0."
                                   % (HEADER, ID_SEP, PICK_SEP))
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--repo", required=True, help="리포 루트(답 파일을 쓰고 커밋할 곳)")
    p.add_argument("--answers", required=True, help="답 입력 파일")
    p.set_defaults(func=cmd_record)

    p = sub.add_parser("render", help="result.md 에 「## intent-critic」 을 덧붙이고 돌려주는 꼴을 쓴다",
                       description="공시 줄들 뒤 마지막 줄이 intent-critic 결과 줄이다. 이 세션 폴더에서 "
                                   "이미 렌더했으면(%s) 덧붙이지 않는다. rc 0." % RENDERED)
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--mode", required=True, choices=("pr", "range"))
    p.set_defaults(func=cmd_render)
    return top


def main(argv: List[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors=UNWRITABLE)
    args = _parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
