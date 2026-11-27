#!/usr/bin/env python3
"""플러그인 평가(claude plugin eval)를 늘 같은 인자로 돌리고 요약 한 줄을 낸다."""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import List, Optional, Tuple

DEFAULT_CAP = "2"

# 평가 명령에 넘기는 환경 — 실행 · 로그인 · 공급자 선택에 쓰는 것만. 나머지는 넘기지 않는다.
PASS_NAMES = frozenset((
    "PATH", "HOME", "USER", "LOGNAME", "SHELL", "TMPDIR", "LANG", "TERM",
    "CLAUDE_CONFIG_DIR",
    "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy",
    "NO_PROXY", "no_proxy", "NODE_EXTRA_CA_CERTS",
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
    "CLAUDE_CODE_USE_FOUNDRY", "CLAUDE_CODE_USE_MANTLE",
    "CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CODE_CERT_STORE",
    "CLAUDE_CODE_CLIENT_CERT", "CLAUDE_CODE_CLIENT_KEY",
    "CLAUDE_CODE_CLIENT_KEY_PASSPHRASE",
))
PASS_PREFIXES = ("LC_", "ANTHROPIC_")
# 클라우드 공급자의 변수는 그 공급자를 고른 때만 넘긴다(선택 변수, 이름들, 접두들).
PROVIDER_VARS = (
    (("CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_MANTLE"), (), ("AWS_",)),
    (("CLAUDE_CODE_USE_VERTEX",),
     ("GOOGLE_APPLICATION_CREDENTIALS", "CLOUD_ML_REGION"), ("VERTEX_REGION_",)),
    (("CLAUDE_CODE_USE_FOUNDRY",), (), ("AZURE_",)),
)


def child_env(environ, dev: Optional[str]) -> dict:
    names = set(PASS_NAMES)
    prefixes = PASS_PREFIXES
    for selectors, extra_names, extra_prefixes in PROVIDER_VARS:
        if any(environ.get(s) for s in selectors):
            names.update(extra_names)
            prefixes = prefixes + extra_prefixes
    env = {k: v for k, v in environ.items()
           if k in names or k.startswith(prefixes)}
    if dev:
        env["PATH"] = dev + os.pathsep + env.get("PATH", "")
    return env


def dev_tool_bin() -> Optional[str]:
    if sys.platform != "darwin" or not shutil.which("xcode-select"):
        return None
    try:
        p = subprocess.run(
            ["xcode-select", "-p"], stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, universal_newlines=True,
        )
    except OSError:
        return None
    if p.returncode != 0:
        return None
    folder = os.path.join(p.stdout.strip(), "usr", "bin")
    return folder if os.path.isdir(folder) else None


def build_command(plugin_dir: str, case: Optional[str], runs: Optional[int],
                  model: Optional[str], max_cost: str, json_path: str,
                  claude: str = "claude") -> List[str]:
    cmd = [claude, "plugin", "eval", plugin_dir, "--eval-dir", "tests/evals",
           "--ablation", "none", "--no-publish", "--trust-plugin",
           "--scaffold", "--allow-tools", "Bash",
           "--max-cost-usd", max_cost, "--json", json_path]
    if case is not None:
        cmd += ["--case", case]
    if runs is not None:
        cmd += ["--runs", str(runs)]
    if model is not None:
        cmd += ["--model", model]
    return cmd


class _ArgParser(argparse.ArgumentParser):
    """틀린 인자도 종료 코드 2 를 쓰지 않는다 — 2 는 「부분」 이다."""

    def error(self, message):
        raise _BadArgs(message)


class _BadArgs(Exception):
    pass


def not_run(why: str) -> str:
    return "plugin-evals: 돌지 못함 — " + why


def _is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def read_result(path: str) -> Tuple[Optional[dict], Optional[str]]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except OSError:
        return None, "결과 파일이 없다"
    except ValueError as e:
        return None, "결과 파일을 읽지 못했다 — JSON 이 아니다 (%s)" % e
    missing = _missing_field(data)
    if missing:
        return None, "결과 파일을 읽지 못했다 — %s 칸이 없거나 꼴이 다르다" % missing
    return data, None


def _missing_field(data) -> Optional[str]:
    if not isinstance(data, dict):
        return "최상위 객체"
    agg = data.get("aggregates")
    if not isinstance(agg, dict):
        return "aggregates"
    for key in ("casesPassed", "casesTotal"):
        if not _is_int(agg.get(key)):
            return "aggregates." + key
    cost = data.get("costUsd")
    if isinstance(cost, bool) or not isinstance(cost, (int, float)):
        return "costUsd"
    cases = data.get("cases")
    if not isinstance(cases, list):
        return "cases"
    for c in cases:
        arms = c.get("arms") if isinstance(c, dict) else None
        if not isinstance(arms, dict) or not isinstance(arms.get("with"), list):
            return "cases[].arms.with"
    return None


def no_session_runs(result: dict) -> int:
    """모든 실행의 turns 가 정수 0 이면 그 실행 수, 아니면 0."""
    runs = [r for c in result["cases"] for r in c["arms"]["with"]]
    if runs and all(isinstance(r, dict) and _is_int(r.get("turns"))
                    and r["turns"] == 0 for r in runs):
        return len(runs)
    return 0


def summary_line(rc: int, result: Optional[dict],
                 why: Optional[str]) -> Tuple[str, int]:
    if result is None:
        return not_run(why or "결과 파일이 없다"), (rc if rc != 0 else 1)
    if not any(c["arms"]["with"] for c in result["cases"]):
        return not_run("돈 실행이 없다"), (rc if rc != 0 else 1)
    idle = no_session_runs(result)
    if idle:
        return not_run("세션이 시작되지 않았다"
                       "(실행 %d회 모두 0턴)" % idle), (rc if rc != 0 else 1)
    if rc not in (0, 1, 2):
        return not_run("평가 명령이 종료 코드 %d 로 끝났다" % rc), rc
    agg = result["aggregates"]
    runs = sum(len(c["arms"]["with"]) for c in result["cases"])
    model = (result.get("suite") or {}).get("modelOverride") or "기본"
    head = {0: "통과", 1: "실패", 2: "부분"}[rc]
    line = "plugin-evals: %s · 케이스 %d/%d · 실행 %d회 · $%.2f · %s" % (
        head, agg["casesPassed"], agg["casesTotal"], runs,
        result["costUsd"], model)
    return line, rc


def copy_plugin(plugin_dir: str, out_dir: str) -> Tuple[Optional[str], Optional[str]]:
    """링크를 풀어 복사한다 — 링크가 든 폴더에서는 평가 세션이 시작되지 않는다."""
    src = os.path.abspath(plugin_dir)
    dst = os.path.join(out_dir, os.path.basename(src) or "plugin")
    reports = os.path.join(src, "tests", "evals")

    def skip(folder, names):
        if os.path.abspath(folder) == reports and "results" in names:
            return ["results"]
        return []

    try:
        shutil.copytree(src, dst, symlinks=False, ignore=skip)
    except shutil.Error as e:
        errors = e.args[0] if e.args and isinstance(e.args[0], list) else []
        first = errors[0] if errors and len(errors[0]) == 3 else None
        why = "%s: %s" % (first[0], first[2]) if first else str(e)
        return None, why
    except (OSError, RecursionError) as e:
        return None, str(e)
    return dst, None


def valid_cap(text: str) -> bool:
    try:
        value = float(text)
    except ValueError:
        return False
    return value > 0 and value == value and value != float("inf")


def main(argv: Optional[List[str]] = None) -> int:
    parser = _ArgParser(
        prog="run_evals.py",
        description="이 레포의 플러그인 폴더와 그 사본에만 쓴다 — "
                    "확인 질문 없이 그 폴더의 준비 스크립트를 돌린다.")
    parser.add_argument("plugin_dir")
    parser.add_argument("--case")
    parser.add_argument("--runs", type=int)
    parser.add_argument("--model")
    parser.add_argument("--max-cost-usd", default=DEFAULT_CAP)
    try:
        args = parser.parse_args(argv)
    except _BadArgs as e:
        print(not_run("인자가 틀렸다 (%s)" % e))
        return 1
    if not os.path.isdir(args.plugin_dir):
        print(not_run("인자가 틀렸다 (플러그인 폴더가 아니다: %s)" % args.plugin_dir))
        return 1
    if args.runs is not None and args.runs < 1:
        print(not_run("인자가 틀렸다 (--runs 는 1 이상 정수여야 한다)"))
        return 1
    if not valid_cap(args.max_cost_usd):
        print(not_run("상한(--max-cost-usd)은 0 보다 큰 수여야 한다"))
        return 1

    env = child_env(os.environ, dev_tool_bin())
    claude = shutil.which("claude", path=env.get("PATH"))
    if not claude:
        print(not_run("평가 명령(claude)을 찾지 못했다"))
        return 1
    out_dir = tempfile.mkdtemp(prefix="plugin-evals-")
    json_path = os.path.join(out_dir, "result.json")
    copy, why = copy_plugin(args.plugin_dir, out_dir)
    if copy is None:
        shutil.rmtree(out_dir, ignore_errors=True)
        print(not_run("플러그인 폴더의 사본을 만들지 못했다 (%s)" % why))
        return 1
    cmd = build_command(copy, args.case, args.runs,
                        args.model, args.max_cost_usd, json_path, claude)
    print("plugin-evals: 결과 파일 " + json_path, file=sys.stderr)
    try:
        proc = subprocess.run(cmd, env=env)
    finally:
        shutil.rmtree(copy, ignore_errors=True)
    rc = proc.returncode if proc.returncode >= 0 else 128 - proc.returncode
    result, why = read_result(json_path)
    line, code = summary_line(rc, result, why)
    print(line)
    return code


if __name__ == "__main__":
    sys.exit(main())
