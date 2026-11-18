#!/usr/bin/env python3
"""devbrew 진입 skill 사전 검사 — 감시줄 한 줄을 낸다.

진입 skill 의 사전 검사 줄이 상수 인자 `<plugin> <skill>` 로 부른다. 사용자 입력은 받지 않는다.

rc 는 늘 0 이다. rc≠0 이면 플랫폼이 skill 호출 전체를 끊고, 헤드리스에서는 그것이 0턴 rc=0
조용한 실패가 된다. 그래서 어떤 실패도 `error` 감시줄로 바꾼다.

형제 모듈을 import 하지 않는다. 심볼릭 링크로 실행되면 sys.path[0] 이 정본 디렉토리
(`shared/entry/`)라서 형제가 풀리지 않는다. kill switch 변수명 도출은
`shared/killswitch/kill_switch_active.py` 와 같다(`-`→`_`, 대문자화, 값이 정확히 "1").
`shared/tests/test_entry_preflight.sh` 가 두 도출을 대조한다.

끄기 변수 표(`switches.md`)는 부른 경로의 플러그인 폴더(스크립트 두 단계 위)에서 읽는다 — 링크를 풀지 않는다.
"""
import os
import subprocess
import sys

PREFIX = "[devbrew-entry]"
TABLE_FILE = "switches.md"
SWITCH_PREFIX = "[devbrew-switch]"
HEADER = "| 이름 | 끄는 것 | 상태 | 대신할 길 |"
SEPARATOR = "|---|---|---|---|"
STATES = ("남음", "은퇴 예정", "은퇴")
SKIP_HOOKS = "DEVBREW_SKIP_HOOKS"
MAX_TABLE_BYTES = 64 * 1024
UPPER_DIGIT = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
TOKEN_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-"


def _one_line(value):
    return " ".join(str(value).split())


def switch_name(plugin):
    return "DEVBREW_" + plugin.upper().replace("-", "_") + "_DISABLE"


def find_root(cwd):
    """(루트, 출처). git 작업 트리면 그 최상위, 아니면 cwd."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, encoding="utf-8", errors="surrogateescape", timeout=10,
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return cwd, "cwd"
    top = proc.stdout.strip()
    if proc.returncode != 0 or not top:
        return cwd, "cwd"
    return top, "git"


def sentinel(argv, environ, cwd):
    if len(argv) != 2 or not all(argv):
        return "{0} error plugin=? skill=? reason=usage: entry_preflight.py <plugin> <skill>".format(PREFIX)
    plugin, skill = argv
    head = "plugin={0} skill={1}".format(_one_line(plugin), _one_line(skill))
    name = switch_name(plugin)
    if environ.get(name) == "1":
        return "{0} disabled {1} switch={2}=1".format(PREFIX, head, name)
    root, source = find_root(cwd)
    line = "{0} ok {1} root={2}".format(PREFIX, head, _one_line(root))
    if source == "cwd":
        line += " root_source=cwd"
    return line


class TableError(Exception):
    def __init__(self, reason):
        Exception.__init__(self, reason)
        self.reason = reason


def table_path(script_path):
    return os.path.join(os.path.dirname(os.path.dirname(script_path)), TABLE_FILE)


def _valid_name(name):
    token = SKIP_HOOKS + "="
    if name.startswith(token):
        parts = name[len(token):].split(":")
        return len(parts) == 2 and all(p and all(c in TOKEN_CHARS for c in p) for p in parts)
    return len(name) > 8 and name.startswith("DEVBREW_") and all(c in UPPER_DIGIT for c in name[8:])


def _read_text(path):
    try:
        with open(path, "rb") as fh:
            raw = fh.read(MAX_TABLE_BYTES + 1)
    except FileNotFoundError:
        raise TableError("표 파일이 없다")
    except OSError:
        raise TableError("표 파일을 열지 못했다")
    if len(raw) > MAX_TABLE_BYTES:
        raise TableError("표 파일이 너무 크다")
    try:
        return raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise TableError("표 파일이 UTF-8 이 아니다")


def _check_frontmatter(lines, plugin):
    if not lines or lines[0] != "---":
        raise TableError("머리 메타(frontmatter)가 없다")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise TableError("머리 메타(frontmatter)가 닫히지 않았다")
    meta = lines[1:end]
    if "type: devbrew-switches" not in meta:
        raise TableError("머리 메타의 type 이 devbrew-switches 가 아니다")
    if "plugin: " + plugin not in meta:
        raise TableError("머리 메타의 plugin 이 {0} 이 아니다".format(_one_line(plugin)))
    return lines[end + 1:]


def _parse_row(line):
    cells = [c.strip() for c in line.strip()[1:-1].split("|")] if line.strip().endswith("|") else []
    if len(cells) != 4:
        raise TableError("행의 칸이 넷이 아니다")
    names = []
    for piece in cells[0].split(" · "):
        if len(piece) < 3 or not (piece.startswith("`") and piece.endswith("`")):
            raise TableError("이름이 백틱으로 싸여 있지 않다")
        name = piece[1:-1]
        if not _valid_name(name):
            raise TableError("이름 꼴이 틀렸다")
        names.append(name)
    if cells[2] not in STATES:
        raise TableError("상태 칸이 남음 · 은퇴 예정 · 은퇴 가 아니다")
    return {"names": names, "what": cells[1], "state": cells[2], "instead": cells[3]}


def read_table(path, plugin):
    lines = [ln.rstrip("\r") for ln in _read_text(path).split("\n")]
    body = _check_frontmatter(lines, plugin)
    table = [i for i, ln in enumerate(body) if ln.startswith("|")]
    if not table or body[table[0]] != HEADER:
        raise TableError("머리줄이 다르다")
    first = table[0]
    if first + 1 >= len(body) or body[first + 1] != SEPARATOR:
        raise TableError("구분줄이 다르다")
    rows = []
    i = first + 2
    while i < len(body) and body[i].startswith("|"):
        rows.append(_parse_row(body[i]))
        i += 1
    if any(ln.startswith("|") for ln in body[i:]):
        raise TableError("표가 둘이다")
    seen = set()
    for row in rows:
        for name in row["names"]:
            if name in seen:
                raise TableError("같은 이름이 두 번 나온다")
            seen.add(name)
    return rows


def active_names(row, environ):
    found = []
    token = SKIP_HOOKS + "="
    tokens = [t.strip() for t in environ.get(SKIP_HOOKS, "").split(",")]
    for name in row["names"]:
        if name.startswith(token):
            if name[len(token):] in tokens:
                found.append(name)
        elif environ.get(name) == "1":
            found.append(name + "=1")
    return found


def switch_lines(rows, environ):
    lines = []
    for row in rows:
        names = active_names(row, environ)
        if not names:
            continue
        what = "{0}({1})".format(row["what"], " · ".join(names))
        if row["state"] == "남음":
            lines.append("{0} 꺼져 있다 — {1}".format(SWITCH_PREFIX, what))
        elif row["state"] == "은퇴 예정":
            lines.append("{0} 꺼져 있다 — {1}. 곧 은퇴한다 — 대신: {2}".format(SWITCH_PREFIX, what, row["instead"]))
        else:
            lines.append("{0} 더 듣지 않는다 — {1}. 대신: {2}".format(SWITCH_PREFIX, what, row["instead"]))
    return lines


def unreadable_line(reason):
    return "{0} 끄기 변수 표를 읽지 못했다 — {1}. 켜진 끄기 변수가 있는지 알 수 없다".format(
        SWITCH_PREFIX, _one_line(reason))


def _extra_lines(argv):
    if len(argv) != 2 or not all(argv):
        return []
    try:
        rows = read_table(table_path(os.path.abspath(__file__)), argv[0])
        return switch_lines(rows, os.environ)
    except TableError as exc:
        return [unreadable_line(exc.reason)]
    except Exception as exc:  # noqa: BLE001 — 표 때문에 감시줄이 사라지면 안 된다
        return [unreadable_line(type(exc).__name__)]


def main():
    argv = sys.argv[1:]
    try:
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, ValueError):
            pass
        line = sentinel(argv, os.environ, os.getcwd())
    except Exception as exc:  # noqa: BLE001 — 어떤 실패도 rc≠0 으로 새지 않는다
        plugin = _one_line(argv[0]) if len(argv) > 0 and argv[0] else "?"
        skill = _one_line(argv[1]) if len(argv) > 1 and argv[1] else "?"
        line = "{0} error plugin={1} skill={2} reason={3}".format(
            PREFIX, plugin, skill, _one_line("{0}: {1}".format(type(exc).__name__, exc)))
    extras = _extra_lines(argv)
    try:
        sys.stdout.write("".join(ln + "\n" for ln in [line] + extras))
        sys.stdout.flush()
    except Exception:  # noqa: BLE001
        # 남은 버퍼를 인터프리터 종료 flush 가 다시 쓰다 깨지면 rc 120 이 된다 — stdout 을 devnull 로.
        try:
            os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        except Exception:  # noqa: BLE001
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
