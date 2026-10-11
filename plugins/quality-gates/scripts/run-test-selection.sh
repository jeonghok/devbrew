#!/usr/bin/env bash
# run-test-selection.sh — 테스트 러너 어댑터 표의 유일 소유자 (차등 테스트).
#
#   detect      <tree>                                 → 어댑터 집합 (runner/granularity/setup_cmd 3줄 × N, 빈 줄 구분)
#   granularity <runner>                               → file|package|bulk (순수 함수)
#   assign      <tree> <assign-file>      < 후보 파일    → 배정 파일을 원자적으로 쓴다
#   run         <tree> <runner> <bulk|per-unit|flaky> <rows-file> <unit>...
#                                                      → 행 파일에 그 unit 들의 행을 원자적으로 병합한다
#   unrun       <rows-file> <runner> <commit|-> <unit>...  → 관측 없는 행(unrun)을 병합한다
#   pending     <rows-file> <unit>...                  → 관측된 행이 아직 없는 unit 을 한 줄씩 낸다
#
# 배정 파일: `<unit>\t<runner|unclaimed>\t<granularity>` 행들 + 마지막 줄
#   `#qg-assign\tadapters=<a,b|->\trows=<N>`
# 행 파일:   `<unit>\t<pass|fail|error|unrun|absent>\t<exit|->\t<bulk|per-unit|flaky|skip>` 행들 + 마지막 줄
#   `#qg-rows\trunner=<runner>\tcommit=<sha|->\trows=<N>\tflaky=<0|1>`
# 두 꼬리 줄은 이 스크립트만 쓴다. diff-test-results.py 가 그것을 요구한다 — 잘린 파일과 빈 결과를
# 가르는 것은 꼬리 줄이다(R17).
#
# 결과는 종료 코드로만 읽는다 — 0=pass · 1=fail · 127=unrun · 그 밖=error(R2~R4). 러너별 출력 파서는 없다.
#
# Exit: 0 = 정상 · 2 = 사용 오류(아무것도 쓰지 않는다) · 3 = 어댑터 사용 불가(run: 해당 unit 을 unrun 으로 병합)
# DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 이면 run 은 저장소 코드를 돌리지 않고 3 으로 끝난다(R22).
set -u

die() { echo "run-test-selection: $*" >&2; exit 2; }

cargo_target_dir_for() { printf '%s/target\n' "$1"; }

# 심볼릭 링크를 끝까지 따라가 최종 대상의 정규화 위치를 낸다. 고리 · 끝이 링크면 실패.
resolve_leaf_dir() {
  local p=$1 hops=0 t
  while [[ -L "$p" && $hops -lt 20 ]]; do
    t=$(readlink "$p") || return 1
    case "$t" in
      /*) p=$t ;;
      *)  p="$(dirname "$p")/$t" ;;
    esac
    hops=$((hops + 1))
  done
  [[ -L "$p" ]] && return 1
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd -P) || return 1
  else
    (cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
  fi
}

# unit 은 트리 안이어야 한다 — 절대경로 · `..` 성분 · 트리 밖으로 풀리는 링크를 거부한다(R20).
unit_within_worktree() {
  local w=$1 u=$2 root d leaf
  case "$u" in
    /*)                            return 1 ;;
    ..|../*|*/../*|*/..)           return 1 ;;
  esac
  root=$(cd "$w" 2>/dev/null && pwd -P) || return 1
  d=$(cd "$w/$(dirname -- "$u")" 2>/dev/null && pwd -P) || return 0
  case "$d" in
    "$root"|"$root"/*) ;;
    *) return 1 ;;
  esac
  if [[ -L "$w/$u" ]]; then
    leaf=$(resolve_leaf_dir "$w/$u") || return 1
    case "$leaf" in
      "$root"|"$root"/*) ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

dir_is_ignored() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$1" check-ignore -q "$2/" 2>/dev/null
}

poetry_in_project() {
  local w=$1
  case "${POETRY_VIRTUALENVS_IN_PROJECT:-}" in
    1|true|True|TRUE)    return 0 ;;
    0|false|False|FALSE) return 1 ;;
  esac
  if [[ -f "$w/poetry.toml" ]] \
     && grep -qE '^[[:space:]]*in-project[[:space:]]*=[[:space:]]*true' "$w/poetry.toml" 2>/dev/null; then
    return 0
  fi
  if command -v poetry >/dev/null 2>&1; then
    local cfg
    cfg=$( (cd "$w" && poetry config virtualenvs.in-project 2>/dev/null) ) || cfg=""
    case "$cfg" in
      true)  return 0 ;;
      false) return 1 ;;
      *)     return 0 ;;
    esac
  fi
  return 0
}

setup_env_dir_of() {
  case "$2" in
    pytest|unittest)
      case "$(python_env_of "$1")" in
        uv|venv) echo .venv ;;
        poetry)  poetry_in_project "$1" && echo .venv || echo "" ;;
        *)       echo "" ;;
      esac ;;
    jest|vitest|npm-script) echo node_modules ;;
    *) echo "" ;;
  esac
}

python_env_of() {
  local w=$1
  if   [[ -f "$w/uv.lock"          ]]; then echo uv
  elif [[ -f "$w/poetry.lock"      ]]; then echo poetry
  elif [[ -f "$w/requirements.txt" ]]; then echo venv
  else echo ambient; fi
}

py_argv() {
  case "$(python_env_of "$1")" in
    uv)     PY_ARGV=(uv run python) ;;
    poetry) PY_ARGV=(poetry run python) ;;
    venv)   PY_ARGV=(.venv/bin/python) ;;
    *)      PY_ARGV=(python3) ;;
  esac
}

granularity_of() {
  case "$1" in
    pytest|unittest|shell|jest|vitest) echo file ;;
    go)                                echo package ;;
    cargo|make|npm-script)             echo bulk ;;
    *) die "unknown runner: $1" ;;
  esac
}

pkg_field() {
  python3 - "$1/package.json" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        cur = json.load(fh)
except Exception:
    sys.exit(1)
for key in sys.argv[2].split("."):
    if not isinstance(cur, dict) or key not in cur:
        sys.exit(1)
    cur = cur[key]
print(cur if isinstance(cur, str) else "1")
PY
}

pkg_json_malformed() {
  [[ -f "$1/package.json" ]] || return 1
  if ! command -v python3 >/dev/null 2>&1; then
    PKG_JSON_REASON=no_parser; return 1
  fi
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' \
    "$1/package.json" >/dev/null 2>&1 && return 1
  PKG_JSON_REASON=parse_error
  return 0
}

has_pytest_config() {
  local w=$1
  [[ -f "$w/pytest.ini" ]] && return 0
  [[ -f "$w/tox.ini"    ]] && grep -q '^\[pytest\]'      "$w/tox.ini"    2>/dev/null && return 0
  [[ -f "$w/setup.cfg"  ]] && grep -q '^\[tool:pytest\]' "$w/setup.cfg"  2>/dev/null && return 0
  [[ -f "$w/pyproject.toml" ]] && grep -q '^\[tool\.pytest' "$w/pyproject.toml" 2>/dev/null && return 0
  return 1
}

# unittest 가 이 파일을 판정할 수 있는가(R21). discover 가 놓치는 것이 하나라도 있으면 claim 하지 않는다:
# 모듈-레벨 bare `def test` · TestCase 를 상속하지 않는 `class Test…` 가 있으면 거부, TestCase 하위클래스나
# `load_tests` 가 있어야 수락.
unittest_can_judge() {
  local f="$1/$2"
  grep -qE '^(async[[:space:]]+)?def[[:space:]]+test' "$f" 2>/dev/null && return 1
  if grep -E '^class[[:space:]]+Test' "$f" 2>/dev/null | grep -qvF 'TestCase'; then
    return 1
  fi
  grep -qE '^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([^)]*TestCase' "$f" 2>/dev/null && return 0
  grep -qE '^[[:space:]]*def[[:space:]]+load_tests[[:space:]]*\(' "$f" 2>/dev/null && return 0
  return 1
}

# 이 레포가 pytest 를 선언했는가 — 이 머신에 pytest 가 깔렸는가가 아니다.
repo_declares_pytest() {
  local w=$1 f
  find "$w" -name .git -prune -o -type f -name 'conftest.py' -print 2>/dev/null | head -1 | grep -q . && return 0
  for f in requirements.txt requirements-dev.txt requirements/dev.txt pyproject.toml setup.cfg tox.ini; do
    [[ -f "$w/$f" ]] && grep -qiE '(^|[^a-z-])pytest(-[a-z0-9]+)*([^a-z-]|$)' "$w/$f" 2>/dev/null && return 0
  done
  return 1
}

has_python_tests() {
  find "$1" -name .git -prune -o -type f \
       \( -name 'test_*.py' -o -name '*_test.py' \) -print 2>/dev/null | head -1 | grep -q .
}

has_exec_shell_tests() {
  find "$1" -name .git -prune -o -type f -perm -u+x -name '*.sh' -path '*/tests/*' \
       -print 2>/dev/null | head -1 | grep -q .
}

setup_cmd_of() {
  local w=$1
  case "$2" in
    pytest|unittest)
      case "$(python_env_of "$w")" in
        uv)     echo 'uv sync --frozen' ;;
        poetry) echo 'poetry install --no-interaction' ;;
        venv)   echo 'python3 -m venv .venv && .venv/bin/python -m pip install -q -r requirements.txt' ;;
        *)      echo '-' ;;
      esac ;;
    jest|vitest|npm-script)
      if   [[ -f "$w/pnpm-lock.yaml"    ]]; then echo 'pnpm install --frozen-lockfile'
      elif [[ -f "$w/yarn.lock"         ]]; then echo 'yarn install --frozen-lockfile'
      elif [[ -f "$w/package-lock.json" ]]; then echo 'npm ci'
      else echo 'npm install --no-audit --no-fund --no-package-lock'; fi ;;
    shell|go|cargo|make) echo '-' ;;
    *) die "unknown runner: $2" ;;
  esac
}

detect_set() {
  local w=$1 out=""
  if has_pytest_config "$w"; then
    out="$out pytest"
  elif has_python_tests "$w" && repo_declares_pytest "$w"; then
    out="$out pytest"
  elif has_python_tests "$w"; then
    out="$out unittest"
  fi

  has_exec_shell_tests "$w" && out="$out shell"

  local has_jest=0 has_vitest=0 js_pick="" test_script=""
  PKG_JSON_REASON=""
  if pkg_json_malformed "$w"; then
    echo "run-test-selection: package.json 이 있으나 파싱에 실패했다 — JS 어댑터(jest·vitest·npm-script) 감지를 건너뛴다 (in $w). 'JS 어댑터 없음' 과 다른 사건이다." >&2
  elif [[ "$PKG_JSON_REASON" == "no_parser" ]]; then
    echo "run-test-selection: python3 가 없어 package.json 을 읽지 못했다 — JS 어댑터 감지를 건너뛴다 (in $w)." >&2
  fi
  pkg_field "$w" devDependencies.jest   >/dev/null 2>&1 && has_jest=1
  pkg_field "$w" devDependencies.vitest >/dev/null 2>&1 && has_vitest=1
  if [[ $has_jest -eq 1 && $has_vitest -eq 1 ]]; then
    test_script=$(pkg_field "$w" scripts.test 2>/dev/null || true)
    case "$test_script" in
      *vitest*) js_pick=vitest ;;
      *jest*)   js_pick=jest ;;
      *)        js_pick=""
                echo "run-test-selection: jest 와 vitest 가 함께 선언됐고 scripts.test 가 어느 쪽도 호출하지 않는다 — npm-script(bulk)로 폴백한다 (in $w)." >&2 ;;
    esac
  elif [[ $has_jest   -eq 1 ]]; then js_pick=jest
  elif [[ $has_vitest -eq 1 ]]; then js_pick=vitest
  fi
  [[ -n "$js_pick" ]] && out="$out $js_pick"

  [[ -f "$w/go.mod"     ]] && out="$out go"
  [[ -f "$w/Cargo.toml" ]] && out="$out cargo"
  [[ -f "$w/Makefile"   ]] && grep -qE '^test:' "$w/Makefile" 2>/dev/null && out="$out make"
  if [[ -z "$js_pick" ]] && pkg_field "$w" scripts.test >/dev/null 2>&1; then
    out="$out npm-script"
  fi

  local r
  for r in $out; do echo "$r"; done
}

runner_available() {
  local w=$1
  case "$2" in
    shell)       command -v bash  >/dev/null 2>&1 ;;
    go)          command -v go    >/dev/null 2>&1 ;;
    cargo)       command -v cargo >/dev/null 2>&1 ;;
    make)        command -v make  >/dev/null 2>&1 ;;
    npm-script)  command -v npm   >/dev/null 2>&1 ;;
    jest|vitest) command -v npx >/dev/null 2>&1 \
                   && ( cd "$w" && npx --no-install "$2" --version ) >/dev/null 2>&1 ;;
    pytest)      ( cd "$w" && "${PY_ARGV[@]}" -m pytest --version ) >/dev/null 2>&1 ;;
    unittest)    ( cd "$w" && "${PY_ARGV[@]}" -c '' ) >/dev/null 2>&1 ;;
    *)           return 1 ;;
  esac
}

# 실행 관문. 순서가 계약이다: kill switch → 이 트리의 감지(R14) → setup 이 만들 환경 디렉토리가
# 무시되는가 → setup(R3) → 러너 가용성(R3). setup 앞에서 디렉토리를 봐야 무시되지 않는 디렉토리에
# 설치하지 않고, 가용성은 setup 뒤에 봐야 setup 이 설치하는 러너를 놓치지 않는다.
adapter_usable() {
  local w=$1 runner=$2 scmd env_dir
  USABLE_REASON=""
  if [[ "${DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST:-}" == "1" ]]; then
    echo "run-test-selection: 차등 테스트가 DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다 — 저장소 코드를 돌리지 않는다 ($runner in $w)" >&2
    USABLE_REASON=kill_switch; return 1
  fi
  if ! detect_set "$w" | grep -qxF -- "$runner"; then
    echo "run-test-selection: 어댑터 사용 불가: $runner — 이 트리가 선언하지 않았다 (in $w)" >&2
    USABLE_REASON=not_detected; return 1
  fi
  scmd=$(setup_cmd_of "$w" "$runner")
  if [[ "$scmd" != "-" ]]; then
    env_dir=$(setup_env_dir_of "$w" "$runner")
    if [[ -n "$env_dir" ]] && ! dir_is_ignored "$w" "$env_dir"; then
      echo "run-test-selection: 어댑터 사용 불가: $runner — setup 이 만드는 '$env_dir/' 를 이 레포가 gitignore 하지 않는다 (in $w)" >&2
      USABLE_REASON=env_dir_not_ignored; return 1
    fi
    if ! ( cd "$w" && sh -c "$scmd" ) >&2 2>&1; then
      echo "run-test-selection: setup 실패: $scmd" >&2
      USABLE_REASON=setup_failed; return 1
    fi
  fi
  PY_ARGV=(python3)
  py_argv "$w"
  if ! runner_available "$w" "$runner"; then
    echo "run-test-selection: 러너 실행 불가: $runner — 도구가 이 머신에 없다 (in $w)" >&2
    USABLE_REASON=runner_missing; return 1
  fi
  return 0
}

case "${1:-}" in
  detect)
    [[ $# -eq 2 ]] || die "usage: detect <tree>"
    w=$2
    [[ -d "$w" ]] || die "not a directory: $w"
    first=1
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      [[ $first -eq 1 ]] || echo
      first=0
      g=$(granularity_of "$r")     || die "unknown runner from detect_set: $r"
      s=$(setup_cmd_of "$w" "$r")  || die "unknown runner from detect_set: $r"
      echo "runner: $r"
      echo "granularity: $g"
      echo "setup_cmd: $s"
    done < <(detect_set "$w")
    exit 0
    ;;
  granularity)
    [[ $# -eq 2 ]] || die "usage: granularity <runner>"
    granularity_of "$2"
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|granularity|assign|run|unrun|pending)"
    ;;
esac
