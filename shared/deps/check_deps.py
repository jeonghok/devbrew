#!/usr/bin/env python3
"""devbrew 의존 목록(`<플러그인>/dependencies.md`)을 읽고 판을 잰다.

하위 명령:
  entry --plugin-root R --need <이름,…>
      진입에서 쓰는 의존의 지금 판을 표의 최소 판과 비교한다. python 행의 지금 판은 이 스크립트를 돌린 해석기의
      판이다. 강도 `멈춤` 행이 없거나 낮거나 판을 못 뽑으면 `멈춤` 줄을 내고 rc 3.
  superpowers --plugin-root R [--base <불러온 superpowers skill 의 기준 폴더 경로>]
      경로의 `superpowers/<판>/skills` 에서 읽은 판을 표의 superpowers 행 판과 비교해 같다 · 다르다 ·
      확인하지 못했다 중 한 줄을 낸다. 알리기만 한다 — 늘 rc 0.
  measure --plugin-root R [--superpowers-base <경로>] [--today YYYY-MM-DD]
      표의 `최소 판` · `잰 날짜` 칸을 지금 깔린 판으로 바꿔 쓴다. 강도 · 없을 때 칸은 그대로 둔다.
      재지 못한 행은 그대로 두고 알린다. `python-hook` 행은 플러그인의 훅 해석기
      (`scripts/devbrew-python.sh`)가 고른 해석기의 판이다.

형제 모듈을 import 하지 않는다. 플러그인마다 `scripts/check_deps.py` 심볼릭 링크로 돌면
sys.path[0] 이 정본 폴더(`shared/deps/`)라서 형제가 풀리지 않는다. 플러그인 루트는 인자로 받는다.

rc: 0 = 끝남(measure 는 못 잰 행이 있어도 알리고 0, superpowers 는 늘 0) · 2 = 사용법 오류 · 3 = 멈춤(의존 목록을 읽지
못했거나, entry 에서 의존이 없거나 낮거나 판을 못 뽑았다).
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile

PREFIX = "[devbrew-deps]"
FILE_NAME = "dependencies.md"
FILE_TYPE = "devbrew-dependencies"
COLUMNS = ("이름", "최소 판", "잰 날짜", "강도", "없을 때")
KEYS = ("name", "min_version", "measured_on", "strength", "when_missing")
STRENGTHS = ("멈춤", "알림", "기록")

_TRIPLE = re.compile(r"(\d+)\.(\d+)\.(\d+)")
HOOK_RESOLVER = os.path.join("scripts", "devbrew-python.sh")
_HOOK_PROBE = 'import sys\nprint("%d.%d.%d" % tuple(sys.version_info[:3]))\n'
FIXES = {
    "python": "Python 3 을 설치하거나 업데이트한다(python3 가 이 판 이상이어야 한다)",
    "git": "git 을 설치하거나 업데이트한다(https://git-scm.com/downloads)",
    "gh": "gh 를 설치하거나 업데이트한다(https://cli.github.com)",
}


class DepsError(ValueError):
    """의존 목록 파일이 깨졌다 — 읽는 쪽은 멈춘다."""


def version_triple(text):
    """판 문자열의 첫 줄에서 첫 `\\d+\\.\\d+\\.\\d+` 를 정수 셋으로. 못 뽑으면 None."""
    if not text:
        return None
    lines = str(text).splitlines()
    if not lines:
        return None
    found = _TRIPLE.search(lines[0])
    if found is None:
        return None
    return int(found.group(1)), int(found.group(2)), int(found.group(3))


def triple_text(triple):
    return "{0}.{1}.{2}".format(*triple)


def _cells(line):
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|"):
        body = body[:-1]
    return [cell.strip() for cell in body.split("|")]


def _is_separator(cells):
    return bool(cells) and all(cell and set(cell) <= set("-: ") and "-" in cell for cell in cells)


def _parse(text, path):
    """(줄 목록, 행 목록). 행마다 `line` 에 그 행의 줄 번호(0부터)를 담는다."""
    lines = text.splitlines(True)
    if not lines or lines[0].strip() != "---":
        raise DepsError("머리말이 없다 — 첫 줄이 `---` 가 아니다 ({0})".format(path))
    meta = {}
    end = None
    for index in range(1, len(lines)):
        stripped = lines[index].strip()
        if stripped == "---":
            end = index
            break
        key, sep, value = stripped.partition(":")
        if sep:
            meta[key.strip()] = value.strip()
    if end is None:
        raise DepsError("머리말이 닫히지 않았다 — 둘째 `---` 가 없다 ({0})".format(path))
    if meta.get("type") != FILE_TYPE:
        raise DepsError("머리말의 type 이 {0} 가 아니다 ({1})".format(FILE_TYPE, path))
    if not meta.get("plugin"):
        raise DepsError("머리말에 plugin 이 없다 ({0})".format(path))

    rows = []
    header_seen = False
    separator_seen = False
    names = set()
    table_ended = False
    for index in range(end + 1, len(lines)):
        stripped = lines[index].strip()
        if not stripped.startswith("|"):
            if header_seen:
                table_ended = True
            continue
        if table_ended:
            raise DepsError("의존 표가 끝난 뒤에 표 줄이 또 있다 ({0}:{1})".format(path, index + 1))
        cells = _cells(stripped)
        if not header_seen:
            if tuple(cells) != COLUMNS:
                raise DepsError("표 머리가 `| {0} |` 가 아니다 ({1}:{2})".format(
                    " | ".join(COLUMNS), path, index + 1))
            header_seen = True
            continue
        if not separator_seen:
            if len(cells) != len(COLUMNS) or not _is_separator(cells):
                raise DepsError("표 머리 다음 줄이 구분 줄이 아니다 ({0}:{1})".format(path, index + 1))
            separator_seen = True
            continue
        if len(cells) != len(COLUMNS):
            raise DepsError("표의 행이 {0}칸이 아니라 {1}칸이다 ({2}:{3})".format(
                len(COLUMNS), len(cells), path, index + 1))
        row = dict(zip(KEYS, cells))
        if not row["name"]:
            raise DepsError("이름 칸이 비었다 ({0}:{1})".format(path, index + 1))
        if row["name"] in names:
            raise DepsError("같은 이름의 행이 둘이다: {0} ({1}:{2})".format(row["name"], path, index + 1))
        if row["strength"] not in STRENGTHS:
            raise DepsError("강도 칸이 {0} 중 하나가 아니다: {1} ({2}:{3})".format(
                " · ".join(STRENGTHS), row["strength"], path, index + 1))
        names.add(row["name"])
        row["line"] = index
        rows.append(row)
    if not header_seen:
        raise DepsError("의존 표가 없다 ({0})".format(path))
    if not rows:
        raise DepsError("의존 표에 행이 없다 ({0})".format(path))
    return lines, rows, meta


def _read_text(path):
    with open(path, "r", encoding="utf-8-sig") as handle:
        return handle.read()


def read_table(path):
    """의존 목록 파일의 행들. 깨졌으면 DepsError."""
    try:
        text = _read_text(path)
    except (OSError, UnicodeDecodeError) as exc:
        raise DepsError("의존 목록을 열지 못했다: {0} ({1})".format(exc, path))
    rows = _parse(text, path)[1]
    return [{key: row[key] for key in KEYS} for row in rows]


def _row_line(row):
    return "| " + " | ".join(row[key] for key in KEYS) + " |\n"


class _Missing(str):
    """프로그램이 아예 없다는 이유 — entry 가 「없음」으로 보인다."""


def _run_version(argv):
    """(판 셋, None) 또는 (None, 이유). 프로그램이 없으면 이유가 _Missing 이다."""
    try:
        proc = subprocess.run(argv, capture_output=True, encoding="utf-8", errors="replace", timeout=60)
    except FileNotFoundError:
        return None, _Missing("{0} 가 없다".format(argv[0]))
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        return None, "{0} 을 실행하지 못했다: {1}".format(" ".join(argv), " ".join(str(exc).split()))
    out = proc.stdout or ""
    if proc.returncode != 0:
        return None, "{0} 이 rc {1} 로 끝났다".format(" ".join(argv), proc.returncode)
    triple = version_triple(out)
    if triple is None:
        first = out.splitlines()[0] if out.splitlines() else ""
        return None, "{0} 출력의 첫 줄에서 판을 뽑지 못했다: {1!r}".format(" ".join(argv), first)
    return triple, None


def _hook_python_version(plugin_root, plugin):
    """훅 해석기가 고른 해석기로 탐침을 돌려 그 판을 잰다. (판 셋, None) 또는 (None, 이유)."""
    resolver = os.path.join(plugin_root, HOOK_RESOLVER)
    if not os.path.isfile(resolver):
        return None, "훅 해석기가 없다: {0}".format(resolver)
    with tempfile.TemporaryDirectory(prefix="devbrew-deps-") as tmp:
        probe = os.path.join(tmp, "probe.py")
        with open(probe, "w", encoding="utf-8") as handle:
            handle.write(_HOOK_PROBE)
        argv = ["/bin/sh", resolver, "--event", "measure", "--plugin", plugin, "--hook", "measure", probe]
        try:
            proc = subprocess.run(argv, capture_output=True, encoding="utf-8", errors="replace", timeout=60,
                                  stdin=subprocess.DEVNULL)
        except (OSError, subprocess.SubprocessError, ValueError) as exc:
            return None, "훅 해석기를 실행하지 못했다: {0}".format(" ".join(str(exc).split()))
    out = proc.stdout or ""
    if proc.returncode != 0:
        err = [line.strip() for line in (proc.stderr or "").splitlines() if line.strip()]
        return None, "훅 해석기가 rc {0} 로 끝났다: {1}".format(
            proc.returncode, err[-1] if err else "stderr 없음")
    if not out.strip():
        return None, ("훅 해석기가 판을 내지 않았다 — 이 플러그인의 훅이 꺼져 있거나(kill switch) 바닥을 "
                      "만족하는 해석기가 없다")
    triple = version_triple(out)
    if triple is None:
        return None, "훅 해석기 출력의 첫 줄에서 판을 뽑지 못했다: {0!r}".format(out.splitlines()[0])
    return triple, None


def superpowers_version(base):
    """skill 기준 폴더 경로(`…/superpowers/<판>/skills/…`)에서 판 셋. 못 읽으면 None."""
    if not base:
        return None
    parts = [part for part in re.split(r"[\\/]+", str(base)) if part]
    for index in range(len(parts) - 2):
        if parts[index] == "superpowers" and parts[index + 2] == "skills":
            return version_triple(parts[index + 1])
    return None


def _measure_row(name, plugin_root, superpowers_base, plugin=""):
    if name == "python":
        return tuple(sys.version_info[:3]), None
    if name == "python-hook":
        return _hook_python_version(plugin_root, plugin)
    if name == "git":
        return _run_version(["git", "--version"])
    if name == "gh":
        return _run_version(["gh", "--version"])
    if name == "claude-code":
        return _run_version(["claude", "--version"])
    if name == "superpowers":
        if not superpowers_base:
            return None, "superpowers skill 의 기준 폴더 경로를 받지 못했다 (--superpowers-base)"
        triple = superpowers_version(superpowers_base)
        if triple is None:
            return None, "기준 폴더 경로에서 superpowers 판을 읽지 못했다: {0}".format(superpowers_base)
        return triple, None
    if name == "quality-gates":
        manifest = os.path.join(plugin_root, "..", "quality-gates", ".claude-plugin", "plugin.json")
        try:
            with open(manifest, "r", encoding="utf-8") as handle:
                version = json.load(handle).get("version")
        except (OSError, ValueError, AttributeError) as exc:
            return None, "quality-gates 의 plugin.json 을 읽지 못했다: {0}".format(" ".join(str(exc).split()))
        triple = version_triple(version if isinstance(version, str) else "")
        if triple is None:
            return None, "quality-gates 의 plugin.json 에서 판을 뽑지 못했다: {0!r}".format(version)
        return triple, None
    return None, "이 이름을 재는 방법이 없다"


def _write_atomic(path, text):
    tmp = "{0}.tmp-{1}".format(path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def measure(plugin_root, superpowers_base=None, today=None):
    """표를 잰 값으로 고쳐 쓴다. (잰 행 [(이름, 판)], 못 잰 행 [(이름, 이유)], 파일 경로)."""
    path = os.path.join(plugin_root, FILE_NAME)
    try:
        text = _read_text(path)
    except (OSError, UnicodeDecodeError) as exc:
        raise DepsError("의존 목록을 열지 못했다: {0} ({1})".format(exc, path))
    lines, rows, meta = _parse(text, path)
    day = today or datetime.date.today().isoformat()
    measured = []
    missed = []
    for row in rows:
        triple, reason = _measure_row(row["name"], plugin_root, superpowers_base, meta["plugin"])
        if triple is None:
            missed.append((row["name"], reason))
            continue
        row["min_version"] = triple_text(triple)
        row["measured_on"] = day
        lines[row["line"]] = _row_line(row)
        measured.append((row["name"], row["min_version"]))
    if measured:
        _write_atomic(path, "".join(lines))
    return measured, missed, path


def entry(plugin_root, needs):
    """(멈춤 줄 목록, 알림 줄 목록, 맞은 [(이름, 판)]). 의존 목록이 깨졌거나 행이 없으면 DepsError."""
    path = os.path.join(plugin_root, FILE_NAME)
    by_name = {row["name"]: row for row in read_table(path)}
    stops, notes, passed = [], [], []
    for name in needs:
        row = by_name.get(name)
        if row is None:
            raise DepsError("의존 목록에 {0} 행이 없다 ({1})".format(name, path))
        floor = version_triple(row["min_version"])
        if floor is None:
            raise DepsError("{0} 행의 최소 판이 비었거나 판이 아니다: {1!r} ({2})".format(
                name, row["min_version"], path))
        triple, reason = _measure_row(name, plugin_root, None)
        if triple is not None and triple >= floor:
            passed.append((name, triple_text(triple)))
            continue
        if triple is not None:
            have = triple_text(triple)
        elif isinstance(reason, _Missing):
            have = "없음"
        else:
            have = "판 못 읽음"
        fix = FIXES.get(name, "{0} 을 설치하거나 업데이트한다".format(name))
        line = "{0} {1} · 필요 {2} 이상 · {3}".format(name, have, triple_text(floor), fix)
        if row["strength"] == "멈춤":
            stops.append("{0} 멈춤 — {1}".format(PREFIX, line))
        elif row["strength"] == "알림":
            notes.append("{0} 알림 — {1}".format(PREFIX, line))
        else:
            passed.append((name, have))
    return stops, notes, passed


def superpowers_check(plugin_root, base):
    """(첫 줄, 이유 또는 None). 첫 줄은 같다 · 다르다 · 확인하지 못했다 중 하나. 멈추지 않는다."""
    unknown = "{0} superpowers 판을 확인하지 못했다".format(PREFIX)
    if not base:
        return unknown, "불러온 superpowers skill 의 기준 폴더 경로를 받지 못했다(--base)"
    have = superpowers_version(base)
    if have is None:
        return unknown, "받은 경로에 superpowers/<판>/skills 꼴이 없다: {0}".format(base)
    path = os.path.join(plugin_root, FILE_NAME)
    try:
        rows = read_table(path)
    except DepsError as exc:
        return unknown, "의존 목록을 읽지 못했다: {0}".format(exc)
    want = None
    for row in rows:
        if row["name"] == "superpowers":
            want = version_triple(row["min_version"])
            break
    if want is None:
        return unknown, "의존 목록에 superpowers 행이 없거나 그 판 칸이 판이 아니다 ({0})".format(path)
    if have == want:
        return "{0} superpowers {1} — 검증한 판과 같다".format(PREFIX, triple_text(have)), None
    return ("{0} 알림 — 설치된 superpowers {1} 이 검증한 판 {2} 과 다르다. 넘김 결과는 돌아온 뒤 대조한다".format(
        PREFIX, triple_text(have), triple_text(want)), None)


def _run_superpowers(args):
    first, reason = superpowers_check(args.plugin_root, args.base)
    print(first)
    if reason:
        print("  이유: {0}".format(reason))
    return 0


def _needs(value):
    names = [part.strip() for part in value.split(",")]
    if any(not part for part in names):
        raise argparse.ArgumentTypeError("쉼표로 나눈 이름 목록이 아니다: {0!r}".format(value))
    return names


def _run_entry(args):
    try:
        stops, notes, passed = entry(args.plugin_root, args.need)
    except DepsError as exc:
        print("{0} 멈춤 — 의존 목록을 읽지 못했다: {1}".format(PREFIX, exc))
        print("할 일: 플러그인을 다시 설치하거나 업데이트한다.")
        return 3
    for line in stops + notes:
        print(line)
    if stops:
        return 3
    print("{0} ok — {1}".format(PREFIX, " · ".join("{0} {1}".format(n, v) for n, v in passed)))
    return 0


def _date(value):
    try:
        return datetime.date.fromisoformat(value).isoformat()
    except ValueError:
        raise argparse.ArgumentTypeError("YYYY-MM-DD 꼴이 아니다: {0}".format(value))


def main(argv=None):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    except (AttributeError, ValueError):
        pass
    parser = argparse.ArgumentParser(prog="check_deps.py")
    commands = parser.add_subparsers(dest="command")
    entry_cmd = commands.add_parser("entry")
    entry_cmd.add_argument("--plugin-root", required=True)
    entry_cmd.add_argument("--need", required=True, type=_needs)
    superpowers_cmd = commands.add_parser("superpowers")
    superpowers_cmd.add_argument("--plugin-root", required=True)
    superpowers_cmd.add_argument("--base")
    measure_cmd = commands.add_parser("measure")
    measure_cmd.add_argument("--plugin-root", required=True)
    measure_cmd.add_argument("--superpowers-base")
    measure_cmd.add_argument("--today", type=_date)
    args = parser.parse_args(argv)
    if args.command == "entry":
        return _run_entry(args)
    if args.command == "superpowers":
        return _run_superpowers(args)
    if args.command != "measure":
        parser.print_usage(sys.stderr)
        return 2
    try:
        measured, missed, path = measure(args.plugin_root, args.superpowers_base, args.today)
    except DepsError as exc:
        print("{0} 멈춤 — 의존 목록을 읽지 못했다: {1}".format(PREFIX, exc))
        print("할 일: 위 자리를 표 모양(`| {0} |`)에 맞게 고친 뒤 다시 잰다.".format(" | ".join(COLUMNS)))
        return 3
    print("{0} 의존 목록의 판을 쟀다 ({1} — 잰 행 {2}개 · 못 잰 행 {3}개)".format(
        PREFIX, path, len(measured), len(missed)))
    for name, version in measured:
        print("  {0} {1}".format(name, version))
    for name, reason in missed:
        print("  {0} 못 쟀다 — {1}. 이 행은 그대로 둔다".format(name, reason))
    if missed:
        print("할 일: 못 잰 이유를 해결한 뒤 measure 를 다시 돌린다 — 판 칸은 손으로 적지 않는다.")
    else:
        print("할 일: 없다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
