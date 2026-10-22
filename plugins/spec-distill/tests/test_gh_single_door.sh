#!/usr/bin/env bash
# gh 를 찾고 실행하는 자리는 한 곳이다(R8 계획 2 · AC20) — spec-distill 은 scripts/gh_repo.py, qg 는 scripts/gh-repo.sh.
# 판독: spec-distill 의 .py 는 ast 로(문자열 grep 은 주석 · 안내 글로 만족된다), qg 의 셸은 주석을 뗀 줄로.
# 예외 하나: 의존 판 측정(shared/deps/check_deps.py — spec-distill 에는 심볼릭 링크)의 argv `["gh", "--version"]` 는
# 레포를 묻지 않는 판 확인이라 문이 아니다. 그 파일에서 그 argv 꼴이 `_run_version(...)` 의 유일한 인자일 때만 PROBE 로
# 따로 내고, 정확히 하나인지 잰다(목록을 더하거나 변수에 담아 고치는 꼴은 문으로 잡는다).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_gh_single_door.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD_SCRIPTS="plugins/spec-distill/scripts"
QG_SCRIPTS="plugins/quality-gates/scripts"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

py_doors() {  # py_doors <파일…> — gh 를 찾거나 argv 첫 칸으로 실행하는 자리마다 `<파일>:<줄>` 한 줄. 끝에 CHECKED n.
  # PROBE_OK(환경 변수)의 실제 경로인 파일에서 argv 가 정확히 ("gh", "--version") 이고 `_run_version` 호출의 유일한 인자면
  # `PROBE <파일>:<줄>` 로 낸다.
  PYTHONIOENCODING=utf-8 python3 -I - "$@" <<'PY'
import ast, os, sys
PROBE_OK = os.path.realpath(os.environ["PROBE_OK"]) if os.environ.get("PROBE_OK") else None
RUNNERS = {"run", "Popen", "call", "check_call", "check_output", "system", "popen", "getoutput", "getstatusoutput",
           "execvp", "execv", "execlp", "spawnlp"}


def name_of(func):
    return func.attr if isinstance(func, ast.Attribute) else func.id if isinstance(func, ast.Name) else None


def is_gh(node):
    return isinstance(node, ast.Constant) and isinstance(node.value, str) and node.value.strip() == "gh"


def shell_gh(node):
    return (isinstance(node, ast.Constant) and isinstance(node.value, str)
            and (node.value.strip() == "gh" or node.value.lstrip().startswith("gh ")))


checked = 0
for path in sys.argv[1:]:
    tree = ast.parse(open(path, encoding="utf-8").read(), path)
    checked += 1
    whiches = {"which"} | {a.asname for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module == "shutil"
                           for a in n.names if a.name == "which" and a.asname}
    lines, probes = set(), set()
    probe_file = PROBE_OK is not None and os.path.realpath(path) == PROBE_OK
    parents = {c: p for p in ast.walk(tree) for c in ast.iter_child_nodes(p)}
    for n in ast.walk(tree):
        hit = False
        if isinstance(n, ast.Call):
            name = name_of(n.func)
            if name in whiches and n.args and is_gh(n.args[0]):
                hit = True                                   # shutil.which("gh") · 별칭 which("gh")
            elif name in RUNNERS and n.args and shell_gh(n.args[0]):
                hit = True                                   # run("gh pr list", shell=True) · system("gh …")
        elif isinstance(n, (ast.List, ast.Tuple)) and n.elts and is_gh(n.elts[0]):
            up = parents.get(n)
            if (probe_file and len(n.elts) == 2 and isinstance(n.elts[1], ast.Constant)
                    and n.elts[1].value == "--version"
                    and isinstance(up, ast.Call) and name_of(up.func) == "_run_version"
                    and len(up.args) == 1 and up.args[0] is n and not up.keywords):
                probes.add(n.lineno)                         # 판 측정 — 레포를 묻지 않는다
                continue
            hit = True                                       # ["gh", "pr", …] — argv 첫 칸
        if hit:
            lines.add(n.lineno)
    for line in sorted(lines):
        print("%s:%d" % (path, line))
    for line in sorted(probes):
        print("PROBE %s:%d" % (path, line))
print("CHECKED %d" % checked)
PY
}

sh_doors() {  # sh_doors <파일…> — 주석을 뗀 줄에서 gh 를 찾는 자리(`command -v gh` · `which gh` · `type -P gh`). 끝에 CHECKED n.
  PYTHONIOENCODING=utf-8 python3 -I - "$@" <<'PY'
import re, sys
PAT = re.compile(r"(?:\bcommand\s+-v|\bwhich|\btype\s+-P)\s+gh(?![\w.-])")
checked = 0
for path in sys.argv[1:]:
    checked += 1
    for i, line in enumerate(open(path, encoding="utf-8").read().splitlines(), 1):
        code = re.sub(r"(^|\s)#.*$", r"\1", line)
        if PAT.search(code):
            print("%s:%d" % (path, i))
print("CHECKED %d" % checked)
PY
}

echo "=== spec-distill: gh 를 찾고 부르는 자리는 gh_repo.py 하나 ==="
PYS=()
while IFS= read -r f; do PYS+=("$ROOT/$f"); done < <(git -C "$ROOT" ls-files -- "$SD_SCRIPTS/*.py")
[ "${#PYS[@]}" -ge 10 ] && ok "spec-distill 스크립트 ${#PYS[@]}개를 읽는다" || no "spec-distill 스크립트를 못 찾았다(${#PYS[@]}개) — 아래 검사가 공허하다"
OUT="$(PROBE_OK="$ROOT/shared/deps/check_deps.py" py_doors ${PYS[@]+"${PYS[@]}"})"
assert_eq "$(printf '%s\n' "$OUT" | grep '^CHECKED ' || true)" "CHECKED ${#PYS[@]}" "파일마다 ast 로 읽었다"
HITS="$(printf '%s\n' "$OUT" | grep -v '^CHECKED ' | grep -v '^PROBE ' | sed "s#^$ROOT/##" || true)"
assert_eq "$(printf '%s\n' "$HITS" | grep -v "^$SD_SCRIPTS/gh_repo\.py:" || true)" "" "gh 를 찾거나 argv 첫 칸으로 부르는 자리가 gh_repo.py 밖에 없다"
assert_eq "$(printf '%s\n' "$OUT" | grep '^PROBE ' | sed "s#^PROBE $ROOT/##; s#:[0-9]*\$##" || true)" "$SD_SCRIPTS/check_deps.py" \
  "판 측정 예외: argv (\"gh\", \"--version\") 는 의존 판 측정 파일(check_deps.py)에 정확히 하나"
assert_contains "$HITS" "$SD_SCRIPTS/gh_repo.py:" "양의 짝: gh_repo.py 에는 gh 찾기가 있다"

echo "=== 판독기 양성 대조 ==="
cat > "$T/bad.py" <<'PY'
import shutil
from shutil import which as find
import subprocess
a = shutil.which("gh")
b = find("gh")
subprocess.run(["gh", "pr", "list"])
subprocess.run(("gh", "api"))
subprocess.run("gh pr view 1", shell=True)
PY
cat > "$T/fine.py" <<'PY'
import shutil, subprocess
msg = "gh 가 없다 — gh 를 설치한다"
subprocess.run(["git", "gh"])
subprocess.run([exe, "pr", "list"])
x = shutil.which("git")
# shutil.which("gh") 는 주석이다
PY
got="$(py_doors "$T/bad.py" | grep -v '^CHECKED ' | sed "s#^$T/##" | tr '\n' ' ')"
assert_eq "$got" "bad.py:4 bad.py:5 bad.py:6 bad.py:7 bad.py:8 " "which · 별칭 which · argv 목록 · argv 튜플 · 셸 문자열을 모두 잡는다"
assert_eq "$(py_doors "$T/fine.py" | grep -v '^CHECKED ' || true)" "" "양성 짝: 안내 글 · 둘째 칸 · 변수 첫 칸 · 다른 이름 · 주석은 잡지 않는다"
cat > "$T/probe.py" <<'PY'
import subprocess
_run_version(["gh", "--version"])
subprocess.run(["gh", "pr", "list"])
subprocess.run(["gh", "--version", "-R", "x/y"])
_run_version(["gh", "--version"] + ["pr", "comment", "1"])
argv = ["gh", "--version"]
argv[1:] = ["pr", "comment", "1"]
subprocess.run(["gh", "--version"])
_run_version(["gh", "--version"], timeout=1)
PY
got="$(PROBE_OK="$T/probe.py" py_doors "$T/probe.py" | grep -v '^CHECKED ' | sed "s#$T/##" | tr '\n' ' ')"
assert_eq "$got" "probe.py:3 probe.py:4 probe.py:5 probe.py:6 probe.py:8 probe.py:9 PROBE probe.py:2 " "판 측정 예외: 그 파일에서도 _run_version 의 유일한 인자인 (\"gh\", \"--version\") 만 빠지고 다른 gh argv 는 잡는다"
case " $got " in *" probe.py:5 "*) ok "판 측정 예외: (\"gh\", \"--version\") 에 다른 목록을 더한 꼴은 잡는다" ;;
  *) no "판 측정 예외: (\"gh\", \"--version\") + [\"pr\", \"comment\", …] 를 놓쳤다" ;; esac
case " $got " in *" probe.py:6 "*) ok "판 측정 예외: 변수에 담아 뒤에서 조각 대입으로 고치는 꼴은 잡는다" ;;
  *) no "판 측정 예외: argv = [\"gh\", \"--version\"] 뒤 조각 대입을 놓쳤다" ;; esac
got="$(PROBE_OK="$T/fine.py" py_doors "$T/probe.py" | grep -v '^CHECKED ' | sed "s#$T/##" | tr '\n' ' ')"
assert_eq "$got" "probe.py:2 probe.py:3 probe.py:4 probe.py:5 probe.py:6 probe.py:8 probe.py:9 " "판 측정 예외: 예외 파일이 아닌 곳의 gh --version 은 잡는다"

echo "=== qg: gh 를 찾는 자리는 gh-repo.sh 하나 ==="
SHS=()
while IFS= read -r f; do SHS+=("$ROOT/$f"); done < <(git -C "$ROOT" ls-files -- "$QG_SCRIPTS/*.sh")
[ "${#SHS[@]}" -ge 5 ] && ok "qg 셸 스크립트 ${#SHS[@]}개를 읽는다" || no "qg 셸 스크립트를 못 찾았다(${#SHS[@]}개) — 아래 검사가 공허하다"
OUT="$(sh_doors ${SHS[@]+"${SHS[@]}"})"
assert_eq "$(printf '%s\n' "$OUT" | grep '^CHECKED ' || true)" "CHECKED ${#SHS[@]}" "qg 셸 스크립트를 모두 읽었다"
HITS="$(printf '%s\n' "$OUT" | grep -v '^CHECKED ' | sed "s#^$ROOT/##" || true)"
assert_eq "$(printf '%s\n' "$HITS" | grep -v "^$QG_SCRIPTS/gh-repo\.sh:" || true)" "" "qg: command -v gh 가 gh-repo.sh 밖에 없다"
assert_contains "$HITS" "$QG_SCRIPTS/gh-repo.sh:" "양의 짝: qg gh-repo.sh 에는 command -v gh 가 있다"

echo "=== 셸 판독기 양성 대조 ==="
printf '%s\n' 'command -v gh >/dev/null || exit 4' 'if which gh; then :; fi' 'p="$(type -P gh)"' > "$T/bad.sh"
printf '%s\n' '# command -v gh 는 주석이다' 'command -v ghq' 'echo "gh 가 없다"' 'command -v git  # which gh' > "$T/fine.sh"
assert_eq "$(sh_doors "$T/bad.sh" | grep -v '^CHECKED ' | sed "s#^$T/##" | tr '\n' ' ')" "bad.sh:1 bad.sh:2 bad.sh:3 " "command -v · which · type -P 를 잡는다"
assert_eq "$(sh_doors "$T/fine.sh" | grep -v '^CHECKED ' || true)" "" "양성 짝: 주석 · 다른 이름 · 안내 글은 잡지 않는다"
finish
