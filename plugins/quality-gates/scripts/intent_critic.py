#!/usr/bin/env python3
"""intent-critic 단계 CLI — 입구 · 설정 · 입력 조립 · 출력 검사 · 거름 · 상한 · 답 기록 · 렌더.

하위 명령은 `intent_critic.py <sub> --help` 가 정본이다. 세션 폴더(`--rd`)의 파일 이름:
  intent-config.txt     config 가 쓴다(answers_dir · max_bytes 와 출처)
  intent-evidence.txt · intent-origin.md · intent-roadmap.md · intent-intent.md ·
  intent-doubts.md · intent-answered.md · intent-plan.txt     prepare 가 쓴다
  intent-prepare-notices.txt  prepare 의 공시 줄(한 줄에 하나) — render 가 결과 절 앞에 싣는다
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

KILL_ENV = "DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC"
DIR_ENV = "DEVBREW_QUALITY_GATES_INTENT_ANSWERS_DIR"
MAX_ENV = "DEVBREW_QUALITY_GATES_INTENT_CRITIC_MAX_BYTES"
DEFAULT_DIR = "docs/qg-intent-answers"
DEFAULT_MAX = 120000
SETTINGS_FILES = (".claude/settings.json", ".claude/settings.local.json")

CONFIG = "intent-config.txt"
EVIDENCE = "intent-evidence.txt"
ORIGIN = "intent-origin.md"
ROADMAP = "intent-roadmap.md"
INTENT = "intent-intent.md"
DOUBTS = "intent-doubts.md"
ANSWERED = "intent-answered.md"
PLAN = "intent-plan.txt"
PREPARE_NOTICES = "intent-prepare-notices.txt"
OUT1 = "intent-critic-1.txt"
OUT2 = "intent-critic-2.txt"
QUESTIONS = "intent-questions.yaml"
RETURN = "intent-return.md"
RESULT = "result.md"

FENCE = "```qg-intent-critic"
RETURN_FENCE = "```qg-intent-return"
CAP = 3
WEIGHTS = {"방향": 0, "기능": 1, "동작": 2}
FILTER_ANSWERS = ("의도다", "잘못 골랐다")
HEADER = "=== id: "
PICK_SEP = " · pick: "
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
NAMES_MISSING = ("바뀐 파일 목록(review-i<N>.names)이 없거나 비어 이 범위가 더한 답 파일을 "
                 "가리지 못함")
# 바뀐 파일 목록이 리뷰 범위가 바꾼 경로를 모두 담는 모드. paths 의 목록은 glob 에 맞는 경로뿐이다.
WHOLE_SCOPE_MODES = ("session", "branch", "topic", "range")
NAMES_PARTIAL = ("리뷰 범위가 paths 이거나 알 수 없어, 바뀐 파일 목록에 없는 답 파일은 이 범위가 "
                 "더했는지 가리지 못함")
RANGE_ADDED = "이 범위가 더한 답 파일"
RANGE_UNKNOWN = "범위 변경 여부를 확인하지 못함"
RANGE_MARKS = {"added": " · " + RANGE_ADDED, "unknown": " · " + RANGE_UNKNOWN}
COMMIT_MESSAGE = "docs(qg-intent): intent-critic 답 %d개 기록"
RECORD_FAILED = "답 기록 실패 %d개 — %s"
UNANSWERED = " · 답하지 않음 %d개"

NO_EVIDENCE = "intent-critic — 근거 없음"
NO_QUESTION = "intent-critic — 질문 없음"
UNREADABLE = "intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)"
ALREADY = "intent-critic — 이 실행은 이미 intent-critic 단계를 돌았다"
SECOND_FAILED = "둘째 호출 출력을 읽지 못함 — 첫째 호출의 후보만 쓴다"

GATE_SKIPS = {
    "aborted": ("intent-critic — 건너뜀(멈춘 실행)", "멈춘 실행"),
    "trivia": ("intent-critic — 건너뜀(작은 수정 — trivia)", "작은 수정 — trivia"),
    "scope-empty": ("intent-critic — 건너뜀(리뷰할 diff 없음)", "리뷰할 diff 없음"),
    "tree-failed": ("intent-critic — 리뷰 트리를 만들지 못함", "리뷰 트리를 만들지 못함"),
}
KILL_LINE = "intent-critic 꺼짐(kill switch)"

# 거름 공시 — 0 이 아닌 것만 이 순서로 낸다.
COUNT_NOTICES = (
    ("evidence", "근거 없어 거름 %d"),
    ("answered", "이미 답한 질문이라 거름 %d"),
    ("over_cap", "상한 넘어 남김 %d"),
    ("unidentified", "정체를 가르지 못함 %d"),
    ("broken", "항목 파손 %d"),
    ("absorbed", "두 호출에서 겹친 후보를 합침 %d"),
)
RETURN_STATES = {"answered": "답함", "ask": "아직 묻지 않음", "over-cap": "상한 넘어 남김"}


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


CONFIG_KEYS = ("answers_dir", "answers_dir_source", "max_bytes", "max_bytes_source")
PLAN_KEYS = ("call", "mode", "tree_root", "answers_root")


def _read_config(rd: str) -> Optional[dict]:
    pairs = _key_values(_read(_path(rd, CONFIG)))
    if _repeated(pairs, CONFIG_KEYS):
        return None
    cfg = dict(pairs)
    if not cfg.get("answers_dir") or not cfg.get("max_bytes", "").isdigit():
        return None
    cfg["max_bytes"] = int(cfg["max_bytes"])
    return cfg


def _read_plan(rd: str) -> Optional[dict]:
    text = _read(_path(rd, PLAN))
    if text is None:
        return None
    pairs = _key_values(text)
    if _repeated(pairs, PLAN_KEYS):
        return None
    plan = {"call": "", "mode": "", "tree_root": "", "answers_root": "", "sources": [],
            "aliases": {}}
    for key, value in pairs:
        if key == "source":
            plan["sources"].append(value)
        elif key == "alias":
            bundle, sep, brief = value.rpartition(ALIAS_SEP)
            if sep:
                plan["aliases"][bundle] = brief
        elif key in PLAN_KEYS:
            plan[key] = value
    return plan


def _read_questions(rd: str) -> Optional[dict]:
    text = _read(_path(rd, QUESTIONS))
    if text is None:
        return None
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError:
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
    except yaml.YAMLError:
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


def _write_return(rd: str, status: str, mode: str, commit: str, rows: List[dict]) -> None:
    cfg = _read_config(rd) or {}
    lines = [RETURN_FENCE,
             "status: " + _scalar(status),
             "mode: " + _scalar(mode or "-"),
             "answers_dir: " + _scalar(cfg.get("answers_dir", "-")),
             "answers_dir_source: " + _scalar(cfg.get("answers_dir_source", "-")),
             "commit: " + _scalar(commit or "-")]
    if not rows:
        lines.append("questions: []")
    else:
        lines.append("questions:")
    for row in rows:
        lines.append("  - id: " + json.dumps(row["id"], ensure_ascii=False))
        lines.append("    state: " + _scalar(row["state"]))
        lines.append("    answer: " + _scalar(row["answer"]))
        lines.append("    wrong_choice: " + row["wrong_choice"])
        lines.append("    file: " + json.dumps(row["file"], ensure_ascii=False))
    lines.append("```")
    _write(_path(rd, RETURN), "\n".join(lines) + "\n")


# ---------------------------------------------------------------- gate

def cmd_gate(args) -> int:
    if os.environ.get(KILL_ENV) == "1":
        _write_return(args.rd, "skipped — " + KILL_LINE, args.mode, "-", [])
        print(KILL_LINE)
        return 0
    if args.path == "final":
        print("intent-gate: run")
        return 0
    line, reason = GATE_SKIPS[args.path]
    _write_return(args.rd, "skipped — " + reason, args.mode, "-", [])
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
    lines = ["answers_dir: %s" % answers_dir, "answers_dir_source: %s" % dir_source,
             "max_bytes: %d" % max_bytes, "max_bytes_source: %s" % max_source]
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


def _answered_lines(answered: dict) -> str:
    lines = []
    for ident in sorted(answered):
        entry = answered[ident]
        first = (entry["observation"].strip().splitlines() or ["-"])[0].strip()
        lines.append("- %s · %s · 관찰: %s" % (ident, entry["answer"], first or "-"))
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
                aliases, notices: List[str]) -> None:
    """줄 단위 계획 파일. 줄마다 써서 다시 읽으면 같은 값이 나오는지 확인하고, 아닌 출처 · 별칭은 쓰지 않고 공시한다."""
    singles = (("call", call), ("mode", mode), ("tree_root", tree_root),
               ("answers_root", answers_root))
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

    e2e = _read(_path(rd, "e2e-record.md"))
    differential = _read(_path(rd, "differential.yaml"))
    ok, evidence_notices = io_.has_evidence(e2e, differential)
    for line in evidence_notices:
        _add_notice(notices, line)
    if not ok:
        _add_notice(notices, NO_EVIDENCE)
        _write_plan(rd, "none", args.mode, tree_root, answers_root, [], {}, notices)
        return "none"

    evidence, _count = io_.build_evidence(e2e, differential)
    built = io_.build_origin(args.repo, args.head, args.review_commit, args.origin, specs)
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
        doubts += INTENT_DOUBTS_MARK + "\n" + intent_moved

    answered, unreadable, why = ia.read_answered_under(tree_root, cfg["answers_dir"])
    if why:
        _add_notice(notices, "답 자리를 읽지 않았다 — " + why)
    if unreadable:
        _add_notice(notices, "읽지 못한 답 파일 %d" % unreadable)

    total = io_.total_bytes(evidence, built["origin"], built["roadmap"], intent_kept, doubts)
    if total > cfg["max_bytes"]:
        call = "single"
        _add_notice(notices, "한 번에 넣음 — 입력 %d바이트가 상한 %d바이트를 넘었다"
                    % (total, cfg["max_bytes"]))
    elif not doubts.strip():
        call = "first-only"
    else:
        call = "split"

    _write(_path(rd, EVIDENCE), evidence)
    _write(_path(rd, ORIGIN), built["origin"])
    _write(_path(rd, ROADMAP), built["roadmap"])
    _write(_path(rd, INTENT), intent_kept)
    _write(_path(rd, DOUBTS), doubts)
    _write(_path(rd, ANSWERED), _answered_lines(answered))
    _write_plan(rd, call, args.mode, tree_root, answers_root, built["sources"],
                built["aliases"], notices)
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
    except yaml.YAMLError:
        return None, "펜스 안 YAML 을 읽지 못함"
    if not isinstance(data, dict) or not isinstance(data.get("questions"), list):
        return None, "questions 목록이 없음"
    return data, ""


def parse_reviewer_output(text: str) -> Optional[dict]:
    """```qg-intent-critic 펜스가 정확히 하나이고 그 YAML 이 `questions` 목록을 가진 dict 면 그 dict."""
    data, _why = _parse_output(text)
    return data


def cmd_check_output(args) -> int:
    data, why = _parse_output(_read(args.file))
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
    dumped = yaml.safe_dump({"questions": data["questions"]}, allow_unicode=True,
                            sort_keys=False)
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


def _observation_changed(value, observation: str, evidence: dict) -> bool:
    if not isinstance(value, dict):
        return False
    previous = value.get("previous")
    if not isinstance(previous, str) or not previous.strip() or previous not in observation:
        return False
    return _cited(value.get("now_lines"), evidence)


def _answered_state(item: dict, ident: str, answered: dict, evidence: dict) -> Optional[str]:
    """이미 답한 질문으로 거를 때의 상태. 거르지 않으면 None."""
    same = item.get("same_as")
    if not isinstance(same, str) or same != ident:
        return None
    prev = answered.get(ident)
    if prev is None or prev["answer"] not in FILTER_ANSWERS:
        return None
    if _observation_changed(item.get("observation_changed"), prev["observation"], evidence):
        return None
    return "wrong-choice-filtered" if prev["answer"] == "잘못 골랐다" else "answered-filtered"


def _unidentified_id(question: str) -> str:
    return "unidentified:" + hashlib.sha1(question.encode("utf-8", UNWRITABLE)).hexdigest()[:12]


def _question_record(item: dict, ident: str, identified: bool, evidence: dict) -> dict:
    observation = []
    for n in item["evidence_lines"]:
        observation.append(evidence[n])
    return {"id": ident, "identified": identified, "state": "",
            "target_source": _text(item.get("target_source")),
            "target_id": _text(item.get("target_id")), "kind": _text(item.get("kind")),
            "weight": _text(item.get("weight")), "quote": _text(item.get("quote")),
            "label": _text(item.get("label")), "question": _text(item.get("question")).strip(),
            "evidence_lines": list(item["evidence_lines"]), "observation": observation}


def _weight_rank(record: dict) -> int:
    return WEIGHTS.get(record["weight"], len(WEIGHTS))


def _candidates(plan: dict, rd: str, ledger: Ledger, notices: List[str]) -> Optional[list]:
    """[(라벨, 호출 번호, 항목)] — 첫째 출력을 쓸 수 없으면 None(셀 수 없음)."""
    call = plan["call"]
    first, first_why = _parse_output(_read(_path(rd, OUT1)))
    second, second_why = _parse_output(_read(_path(rd, OUT2)))
    if call == "single":
        main, main_why, extra = second, "한 번에 넣은 호출 — " + second_why, None
    elif call in ("first-only", "split"):
        main, main_why, extra = first, "첫째 호출 — " + first_why, None
        if call == "split":
            extra = second
    else:
        main, main_why, extra = None, "준비 파일의 갈래를 모름(%s)" % (call or "-"), None
    if main is None:
        ledger.source_failed("intent-critic", main_why, primary=True)
        ledger.uncountable("intent-critic 후보", main_why)
        return None
    out = []
    number = 1 if call != "single" else 2
    for i, item in enumerate(main["questions"], 1):
        out.append(("%s %d" % ("첫째" if number == 1 else "한 번", i), number, item))
    if call == "split" and extra is None:
        ledger.source_failed("intent-critic", "둘째 호출 — " + second_why, primary=False)
        notices.append(SECOND_FAILED)
    elif extra is not None:
        for i, item in enumerate(extra["questions"], 1):
            out.append(("둘째 %d" % i, 2, item))
    return out


def _range_names(rd: str) -> Optional[set]:
    """마지막 반복의 `review-i<N>.names`(리뷰 범위가 바꾼 경로, 한 줄에 하나). 없으면 None."""
    try:
        names = os.listdir(rd)
    except OSError:
        names = []
    best, best_name = -1, None
    for name in names:
        number = name[len(NAMES_PREFIX):-len(NAMES_SUFFIX)]
        if (name.startswith(NAMES_PREFIX) and name.endswith(NAMES_SUFFIX) and number.isdigit()
                and number.isascii() and int(number) > best):
            best, best_name = int(number), name
    text = _read(_path(rd, best_name)) if best_name is not None else None
    if text is None:
        return None
    out = set()
    for line in text.split("\n"):
        if line:
            out.add(line)
    # 기준선이 degraded 면 review-diff.sh 가 목록을 일부러 비워 둔다 — 빈 목록은 「바뀐 것 없음」이 아니라 「모름」이다.
    return out or None


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


def _answer_rel(answers_dir: str, path: str) -> str:
    return answers_dir.rstrip("/") + "/" + os.path.basename(path)


def _judge(cands: list, plan: dict, rd: str, ledger: Ledger, counts: dict, answered: dict,
           ids: Optional[set], whole: bool) -> list:
    evidence = _evidence_lines(rd)
    answers_dir = (_read_config(rd) or {}).get("answers_dir", "")
    first_ids = set()
    remaining: List[dict] = []
    decided: List[dict] = []
    for label, number, item in cands:
        if not isinstance(item, dict) or not _text(item.get("question")).strip():
            ledger.hold(label, "항목 파손")
            counts["broken"] += 1
            continue
        if not _cited(item.get("evidence_lines"), evidence):
            ledger.suppressed(label, "근거 없어 거름")
            counts["evidence"] += 1
            continue
        ident = _identity(item, plan)
        if ident is not None and number == 2 and plan["call"] == "split" and ident in first_ids:
            ledger.absorbed(label, ident)
            counts["absorbed"] += 1
            continue
        if ident is None:
            counts["unidentified"] += 1
            record = _question_record(item, _unidentified_id(_text(item.get("question")).strip()),
                                      False, evidence)
        else:
            if number == 1:
                first_ids.add(ident)
            record = _question_record(item, ident, True, evidence)
            state = _answered_state(item, ident, answered, evidence)
            if state is not None:
                ledger.suppressed(label, "이미 답한 질문")
                counts["answered"] += 1
                record["state"] = state
                record["previous_answer"] = answered[ident]["answer"]
                record["answer_file"] = _answer_rel(answers_dir, answered[ident]["path"])
                record["range_mark"] = _range_mark(answered[ident]["path"], ids, whole)
                decided.append(record)
                continue
        record["label_in_run"] = label
        remaining.append(record)
    ordered = sorted(remaining, key=_weight_rank)
    for i, record in enumerate(ordered):
        label = record.pop("label_in_run")
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
    counts = {"evidence": 0, "answered": 0, "over_cap": 0, "unidentified": 0, "broken": 0,
              "absorbed": 0}
    plan = _read_plan(rd)
    questions: List[dict] = []
    if plan is None:
        status, call = "uncountable", "-"
        ledger.uncountable("intent-critic 후보", "준비 파일(%s)이 없음" % PLAN)
    elif plan["call"] == "none":
        status, call = "no-evidence", "none"
    else:
        call = plan["call"]
        cands = _candidates(plan, rd, ledger, notices)
        if cands is None:
            status = "uncountable"
        else:
            status = "ran"
            answered = _load_answered(plan, rd, notices)
            ids = _range_identities(rd, plan["tree_root"])
            whole = args.review_mode in WHOLE_SCOPE_MODES
            questions = _judge(cands, plan, rd, ledger, counts, answered, ids, whole)
            if counts["answered"] and ids is None:
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
                          "questions": questions})
    _emit(notices)
    print("intent-ask: %d" % asked)
    return 0


# ---------------------------------------------------------------- record

def _answer_header(line: str, known: dict, seen: dict) -> Optional[tuple]:
    """머리 줄이면 (정체, 고른 것). 알려진 묻는 질문의 정체일 때만 머리다."""
    if not line.startswith(HEADER):
        return None
    ident, sep, pick = line[len(HEADER):].partition(PICK_SEP)
    pick = pick.rstrip()
    if not sep or pick not in ia.ANSWERS + (TYPED,):
        return None
    if seen.get(ident, 0) >= known.get(ident, 0):
        return None
    return ident, pick


def parse_answer_input(text: str, known: dict) -> tuple:
    """`=== id: <정체> · pick: <답|typed>` 머리로 가른 답들. 머리 아닌 줄은 앞 머리의 원문이다.

    → (답들, 첫 머리 앞의 빈 줄 아닌 줄 수). 첫 머리 앞의 글은 붙일 질문이 없어 읽지 못한다.
    """
    seen: dict = {}
    entries: List[dict] = []
    current: Optional[dict] = None
    orphan = 0
    for line in text.split("\n"):
        head = _answer_header(line.rstrip("\r"), known, seen)
        if head is not None:
            seen[head[0]] = seen.get(head[0], 0) + 1
            current = {"id": head[0], "pick": head[1], "lines": []}
            entries.append(current)
        elif current is not None:
            current["lines"].append(line)
        elif line.strip():
            orphan += 1
    return entries, orphan


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


def _store_record_notices(rd: str, data: Optional[dict], notices: List[str]) -> None:
    """record 의 공시를 거르기 결과에 남겨 render 가 result.md 에 보이게 한다."""
    if data is None or not notices:
        return
    data["record_notices"] = list(data.get("record_notices") or []) + notices
    _write_questions(rd, data)


def _record(args) -> tuple:
    """(공시 줄들, 기록한 답 파일 수)."""
    plan = _read_plan(args.rd)
    data = _read_questions(args.rd)
    if plan is None:
        notices = ["답을 기록하지 못했다 — 준비 파일(%s)을 읽지 못함" % PLAN]
        _store_record_notices(args.rd, data, notices)
        return notices, 0
    if plan["mode"] == "range":
        return [], 0
    cfg = _read_config(args.rd)
    text = _read(args.answers)
    if data is None or cfg is None or text is None:
        notices = ["답을 기록하지 못했다 — 거르기 결과 · 설정 · 답 입력 중 읽지 못한 것이 있다"]
        _store_record_notices(args.rd, data, notices)
        return notices, 0
    known: dict = {}
    pending: dict = {}
    for record in data["questions"]:
        if isinstance(record, dict) and record.get("state") == "ask":
            known[record["id"]] = known.get(record["id"], 0) + 1
            pending.setdefault(record["id"], []).append(record)
    entries, orphan = parse_answer_input(text, known)
    notices = []
    if not entries and known and text.strip():
        asked = 0
        for ident in known:
            asked += known[ident]
        notices.append("답 입력에서 묻는 질문의 머리를 찾지 못함 — 묻는 질문 %d개" % asked)
    if orphan:
        notices.append("머리 앞의 답 글을 읽지 못함 %d줄" % orphan)
    if not entries:
        _store_record_notices(args.rd, data, notices)
        return notices, 0
    data["record_notices"] = list(data.get("record_notices") or []) + notices
    answers_dir = cfg["answers_dir"]
    target = _review_target(args.repo, answers_dir)
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    directory = os.path.join(args.repo, answers_dir)
    taken: set = set()
    files = []
    pairs = []
    for entry in entries:
        record = pending[entry["id"]].pop(0)
        answer, raw = _read_pick(entry)
        name, at = _unique_name(record["id"], now, taken, directory)
        files.append((name, ia.render_answer_file(
            record["id"], record.get("question", ""), record.get("quote", ""),
            record.get("label", ""), record.get("observation") or [], answer, raw, target, at)))
        pairs.append((record, answer))
    paths, write_error = ia.write_answer_files(args.repo, answers_dir, files)
    # 답 파일이 생긴 질문만 답함이다. 파일을 쓰지 못한 질문은 묻는 상태로 남기고 수와 사유를 공시한다.
    for i, (record, answer) in enumerate(pairs):
        if i < len(paths):
            record["state"] = "answered"
            record["answer"] = answer
            record["file"] = paths[i]
        else:
            record["record_failed"] = True
    if len(pairs) > len(paths):
        notices.append(RECORD_FAILED % (len(pairs) - len(paths),
                                        write_error or "답 파일이 없다"))
        data["record_notices"].append(notices[-1])
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


def _outcome(plan: Optional[dict], data: Optional[dict], mode: str) -> tuple:
    """(상태, 결과 줄, 공시 줄들)."""
    notices = []
    if data is not None:
        notices = list(data.get("notices") or []) + list(data.get("record_notices") or [])
    if plan is None:
        return "uncountable", UNREADABLE, ["준비 파일(%s)을 읽지 못함" % PLAN] + notices
    if plan["call"] == "none":
        return "skipped — 근거 없음", NO_EVIDENCE, []
    if data is None:
        return "uncountable", UNREADABLE, ["거르기 결과(%s)가 없음" % QUESTIONS]
    if data.get("status") == "uncountable":
        return "uncountable", UNREADABLE, notices
    asked = answered = wrong = unanswered = 0
    for record in data["questions"]:
        state = record.get("state")
        if state in ("ask", "answered"):
            asked += 1
        if state == "answered":
            answered += 1
            if record.get("answer") == "잘못 골랐다":
                wrong += 1
        elif state == "ask" and not record.get("record_failed"):
            unanswered += 1   # 묻고도 답을 받지 못한 질문 — 답 기록 실패는 따로 공시된다
    counts = data.get("counts") or {}
    if asked == 0:
        if counts.get("evidence") and not counts.get("answered"):
            return "ran", NO_EVIDENCE, notices
        return "ran", NO_QUESTION, notices
    if mode == "range":
        return "ran", "intent-critic — 질문 %d개 아직 묻지 않음(범위 모드)" % asked, notices
    line = "intent-critic — 질문 %d개를 물었다 · 답 %d개(잘못 골랐다 %d개)" % (asked, answered, wrong)
    if unanswered:
        line += UNANSWERED % unanswered
    return "ran", line, notices


def _rows(data: Optional[dict], mode: str) -> List[dict]:
    rows = []
    for record in (data or {}).get("questions") or []:
        state = record.get("state")
        if state in RETURN_STATES:
            answer = record.get("answer") or "-"
            rows.append({"id": _text(record.get("id")), "state": RETURN_STATES[state],
                         "answer": answer, "wrong_choice": "yes" if answer == "잘못 골랐다" else "no",
                         "file": "-" if mode == "range" else (record.get("file") or "-"),
                         "question": record.get("question", "")})
    return rows


def _section(line: str, notices: List[str], data: Optional[dict], rows: List[dict]) -> str:
    out = ["", SECTION, "", SECTION_LEAD, "", "- " + line]
    for notice in notices:
        out.append("- " + notice)
    if data and data.get("commit_line"):
        out.append("- " + data["commit_line"])
    if rows:
        out += ["", "| 정체 | 상태 | 답 | 답 파일 | 질문 |", "|---|---|---|---|---|"]
    for row in rows:
        out.append("| %s | %s | %s | %s | %s |" % (_cell(row["id"]), row["state"],
                                                   _cell(row["answer"]), _cell(row["file"]),
                                                   _cell(row["question"])))
    over = []
    wrong = []
    filtered = []
    for record in (data or {}).get("questions") or []:
        item = "- %s — %s" % (_text(record.get("id")), _cell(record.get("question")))
        if record.get("state") == "over-cap":
            over.append(item)
        elif record.get("state") == "wrong-choice-filtered":
            wrong.append(item)
        if record.get("state") in ("answered-filtered", "wrong-choice-filtered"):
            mark = RANGE_MARKS.get(record.get("range_mark"), "")
            filtered.append("- %s · %s · %s%s — %s" % (
                _cell(record.get("id")), _cell(record.get("previous_answer")),
                _cell(record.get("answer_file")), mark, _cell(record.get("question"))))
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
    status, line, notices = _outcome(plan, data, args.mode)
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
    _append(result_path, lead + _section(line, shown, data, rows))
    commit = "-" if args.mode == "range" else _text((data or {}).get("commit") or "-")
    _write_return(rd, status, args.mode, commit, rows)
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
                       description="환경 변수 %s · %s 를 읽어 intent-config.txt 네 줄을 쓴다. 리뷰 "
                                   "트리의 .claude/settings.json · settings.local.json 이 base 와 그 키가 "
                                   "다르면 기본값(default-settings-changed). --base - 는 base 를 "
                                   "모름 — 그때 리뷰 트리 설정에 그 키가 있으면 바뀐 것으로 본다."
                                   % (DIR_ENV, MAX_ENV))
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--repo", required=True, help="리포 루트(base 쪽 설정을 git show 로 읽는다)")
    p.add_argument("--base", required=True, help="기준 rev, 모르면 -")
    p.add_argument("--project-dir", required=True, help="리뷰 트리(리뷰 쪽 설정을 읽는다)")
    p.set_defaults(func=cmd_config)

    p = sub.add_parser("prepare", help="근거 · 원문 · 로드맵 · 의도 · 의심 · 답을 조립한다",
                       description="intent-config.txt 가 먼저 있어야 한다. 공시 줄들 뒤 "
                                   "「intent-call: <none|first-only|split|single>」. rc 0 · 입력 못 읽음 4.")
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
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("check-output", help="리뷰어 응답을 읽을 수 있나 본다",
                       description="qg-intent-critic 펜스 하나 + questions 목록이면 「readable」 rc 0, "
                                   "아니면 「unreadable: <사유>」 rc 3.")
    p.add_argument("file", help="리뷰어 응답 파일")
    p.set_defaults(func=cmd_check_output)

    p = sub.add_parser("doubts-append", help="첫째 호출의 후보를 의심 파일 끝에 덧붙인다",
                       description="intent-critic-1.txt 의 후보를 intent-doubts.md 끝 「%s」 아래에 "
                                   "한 번만 덧붙인다. 마지막 줄 「doubts-append: <n>」." % FIRST_CANDIDATES)
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.set_defaults(func=cmd_doubts_append)

    p = sub.add_parser("filter", help="후보를 거르고 상한을 둔다",
                       description="intent-plan.txt 의 call 로 응답을 고른다(first-only=1 · single=2 · "
                                   "split=1 과 2 의 합). 근거 · 정체 · 이미 답함 · 상한 순으로 거르고 "
                                   "intent-questions.yaml 을 쓴다. 공시 줄들 뒤 「intent-ask: <k>」. rc 0.")
    p.add_argument("--rd", required=True, help="qg 세션 폴더")
    p.add_argument("--review-mode", default="-",
                   help="마지막 반복의 리뷰 diff 모드(review-diff.sh 의 mode: 값). %s 이면 바뀐 파일 "
                        "목록이 범위 전체다. paths · 모름(-) · 그 밖의 값이면 목록에 없는 답 파일을 "
                        "「더하지 않음」 이 아니라 「모름」 으로 표시한다." % " · ".join(WHOLE_SCOPE_MODES))
    p.set_defaults(func=cmd_filter)

    p = sub.add_parser("record", help="답 파일을 docs 답 자리에 쓰고 그 파일만 커밋한다",
                       description="입력 꼴: 「%s<정체>%s<의도다|잘못 골랐다|지금은 모르겠다|typed>」 머리 "
                                   "줄 뒤 다음 머리 전까지가 답 원문. 묻는 질문의 정체가 아닌 머리는 원문으로 "
                                   "읽는다. 범위 모드면 아무것도 쓰지 않는다. 마지막 줄 「record: <n>」. rc 0."
                                   % (HEADER, PICK_SEP))
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
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = _parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
