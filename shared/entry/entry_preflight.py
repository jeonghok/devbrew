#!/usr/bin/env python3
"""devbrew 진입 skill 사전 검사 — 감시줄 한 줄을 낸다.

진입 skill 의 사전 검사 줄이 상수 인자 `<plugin> <skill>` 로 부른다. 사용자 입력은 받지 않는다.

rc 는 늘 0 이다. rc≠0 이면 플랫폼이 skill 호출 전체를 끊고, 헤드리스에서는 그것이 0턴 rc=0
조용한 실패가 된다. 그래서 어떤 실패도 `error` 감시줄로 바꾼다.

형제 모듈을 import 하지 않는다. 심볼릭 링크로 실행되면 sys.path[0] 이 정본 디렉토리
(`shared/entry/`)라서 형제가 풀리지 않는다. kill switch 변수명 도출은
`shared/killswitch/kill_switch_active.py` 와 같다(`-`→`_`, 대문자화, 값이 정확히 "1").
`shared/tests/test_entry_preflight.sh` 가 두 도출을 대조한다.
"""
from __future__ import annotations

import os
import subprocess
import sys

PREFIX = "[devbrew-entry]"


def _one_line(value):
    return " ".join(str(value).split())


def switch_name(plugin):
    return "DEVBREW_" + plugin.upper().replace("-", "_") + "_DISABLE"


def find_root(cwd):
    """(루트, 출처). git 작업 트리면 그 최상위, 아니면 cwd."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, text=True, timeout=10,
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
    try:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except Exception:  # noqa: BLE001
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
