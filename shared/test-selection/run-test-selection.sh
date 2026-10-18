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
  python3 -I -X utf8 - "$1/package.json" "$2" <<'PY' 2>/dev/null
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
  python3 -I -X utf8 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' \
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

COMMIT_RE='^([0-9a-f]{40}|[0-9a-f]{64}|-)$'

# 행 파일을 읽어 ROWS_UNIT/ROWS_LINE 배열과 꼬리 값(T_RUNNER/T_COMMIT/T_FLAKY)을 채운다.
# 없는 파일은 빈 행 집합이다. 꼬리 줄이 정확히 하나, 마지막 줄이 아니거나 행 수가 다르면 die.
ROWS_UNIT=(); ROWS_LINE=(); T_RUNNER=""; T_COMMIT=""; T_FLAKY=0; T_ROWS=""
load_rows() {
  local f=$1 line n=0 tails=0 last=""
  ROWS_UNIT=(); ROWS_LINE=(); T_RUNNER=""; T_COMMIT=""; T_FLAKY=0; T_ROWS=""
  [[ -e "$f" ]] || return 0
  [[ -f "$f" ]] || die "행 파일이 일반 파일이 아니다: $f"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    last=$line
    if [[ "$line" == '#qg-rows'$'\t'* ]]; then
      tails=$((tails + 1))
      T_RUNNER=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^runner=//p')
      T_COMMIT=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^commit=//p')
      T_FLAKY=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^flaky=//p')
      T_ROWS=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^rows=//p')
      continue
    fi
    ROWS_UNIT+=("${line%%$'\t'*}")
    ROWS_LINE+=("$line")
    n=$((n + 1))
  done < "$f"
  [[ $tails -eq 1 && "$last" == '#qg-rows'$'\t'* ]] || die "행 파일 꼬리 줄이 정확히 하나의 마지막 줄이 아니다: $f"
  [[ "${T_ROWS:-}" == "$n" ]] || die "행 파일 행 수 불일치(꼬리 ${T_ROWS:-?} · 실제 $n): $f"
  [[ -n "$T_RUNNER" ]] || die "행 파일 꼬리의 runner= 가 비었다: $f"
  [[ "$T_COMMIT" =~ $COMMIT_RE ]] || die "행 파일 꼬리의 commit= 가 sha 도 '-' 도 아니다: $f"
  [[ "$T_FLAKY" == "0" || "$T_FLAKY" == "1" ]] || die "행 파일 꼬리의 flaky= 가 0·1 이 아니다: $f"
}

# 새 행(NEW_UNIT/NEW_LINE)을 기존 행에 병합해 원자적으로 쓴다. 같은 unit 은 교체한다(R7).
write_rows() {
  local f=$1 runner=$2 commit=$3 flaky=$4 tmp i j keep n=0
  tmp=$(mktemp "$(dirname "$f")/.qg-rows.XXXXXX") || die "임시 파일을 만들 수 없다: $(dirname "$f")"
  {
    for ((i = 0; i < ${#ROWS_UNIT[@]}; i++)); do
      keep=1
      for ((j = 0; j < ${#NEW_UNIT[@]}; j++)); do
        [[ "${ROWS_UNIT[$i]}" == "${NEW_UNIT[$j]}" ]] && { keep=0; break; }
      done
      [[ $keep -eq 1 ]] && { printf '%s\n' "${ROWS_LINE[$i]}"; n=$((n + 1)); }
    done
    for ((j = 0; j < ${#NEW_UNIT[@]}; j++)); do
      printf '%s\n' "${NEW_LINE[$j]}"; n=$((n + 1))
    done
    printf '#qg-rows\trunner=%s\tcommit=%s\trows=%s\tflaky=%s\n' "$runner" "$commit" "$n" "$flaky"
  } > "$tmp" || { rm -f "$tmp"; die "행 파일을 쓰지 못했다: $f"; }
  mv -f "$tmp" "$f" || { rm -f "$tmp"; die "행 파일을 옮기지 못했다: $f"; }
}

# 같은 unit 이 인자에 두 번 오면 거부한다 — 병합이 입력 순서에 의존하게 된다.
reject_duplicate_units() {
  local seen="" u
  for u in "$@"; do
    printf '%s\n' "$seen" | grep -qxF -- "$u" && die "unit 이 두 번 왔다: $u"
    seen="$seen
$u"
  done
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
  assign)
    [[ $# -eq 3 ]] || die "usage: assign <tree> <assign-file>   # stdin: 후보 파일 경로"
    w=$2; out=$3
    [[ -d "$out" ]] && die "배정 파일 경로가 디렉토리다: $out"
    rm -f -- "$out" || die "이전 배정 파일을 지우지 못했다: $out"
    [[ -d "$w" ]] || die "not a directory: $w"
    [[ -d "$(dirname -- "$out")" ]] || die "배정 파일의 디렉토리가 없다: $out"
    adapters=$(detect_set "$w")
    has_adapter() { printf '%s\n' "$adapters" | grep -qxF -- "$1"; }
    # bulk 러너는 어느 파일 어댑터도 claim 하지 않은 잔여를 흡수한다. 둘 이상이면 첫째만 흡수자다.
    absorber=""; unused_bulk=""
    for r in cargo make npm-script; do
      if has_adapter "$r"; then
        if [[ -z "$absorber" ]]; then absorber="$r"; else unused_bulk="$unused_bulk $r"; fi
      fi
    done
    py=""; has_adapter pytest && py=pytest; has_adapter unittest && py=unittest
    js=""; has_adapter jest   && js=jest;   has_adapter vitest   && js=vitest
    tmp=$(mktemp "$(dirname -- "$out")/.qg-assign.XXXXXX") || die "임시 파일을 만들 수 없다: $out"
    residual=0; seen=""; n=0
    emit() {   # emit <unit> <runner> <granularity> — 같은 unit 은 한 번만
      printf '%s\n' "$seen" | grep -qxF -- "$1" && return 0
      printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp" || { rm -f "$tmp"; die "배정 파일을 쓰지 못했다: $out"; }
      seen="$seen
$1"
      n=$((n + 1))
    }
    while IFS= read -r f || [[ -n "$f" ]]; do
      [[ -z "$f" ]] && continue
      if ! unit_within_worktree "$w" "$f"; then
        emit "$f" unclaimed file; continue
      fi
      claimed=""
      case "$f" in
        *_test.go) has_adapter go && claimed=go ;;
      esac
      if [[ -z "$claimed" && -n "$py" ]]; then
        case "$f" in test_*.py|*/test_*.py|*_test.py) claimed="$py" ;; esac
        if [[ "$claimed" == "unittest" ]] && ! unittest_can_judge "$w" "$f"; then
          claimed=""
        fi
      fi
      if [[ -z "$claimed" ]] && has_adapter shell; then
        case "$f" in
          tests/*.sh|*/tests/*.sh) [[ -x "$w/$f" ]] && claimed=shell ;;
        esac
      fi
      if [[ -z "$claimed" && -n "$js" ]]; then
        case "$f" in
          *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.*) claimed="$js" ;;
        esac
      fi
      if [[ -n "$claimed" ]]; then
        if [[ "$(granularity_of "$claimed")" == "package" ]]; then
          emit "$(dirname -- "$f")" "$claimed" package
        else
          emit "$f" "$claimed" file
        fi
      elif [[ -n "$absorber" ]]; then
        residual=1
      else
        emit "$f" unclaimed file
      fi
    done
    [[ $residual -eq 1 ]] && emit BULK "$absorber" bulk
    for r in $unused_bulk; do
      echo "run-test-selection: 미실행 러너: $r (bulk 잔여는 $absorber 가 흡수)" >&2
    done
    adapter_list=$(printf '%s\n' "$adapters" | sed '/^$/d' | paste -sd, -)
    printf '#qg-assign\tadapters=%s\trows=%s\n' "${adapter_list:--}" "$n" >> "$tmp" \
      || { rm -f "$tmp"; die "배정 파일을 쓰지 못했다: $out"; }
    mv -f "$tmp" "$out" || { rm -f "$tmp"; die "배정 파일을 옮기지 못했다: $out"; }
    exit 0
    ;;
  run)
    [[ $# -ge 6 ]] || die "usage: run <tree> <runner> <bulk|per-unit|flaky> <rows-file> <unit>..."
    w=$2; runner=$3; mode=$4; rows=$5; shift 5
    [[ -d "$w" ]] || die "not a directory: $w"
    case "$mode" in bulk|per-unit|flaky) ;; *) die "unknown mode: $mode (expected bulk|per-unit|flaky)" ;; esac
    gran=$(granularity_of "$runner") || die "unknown runner: $runner"
    [[ -d "$(dirname -- "$rows")" ]] || die "행 파일의 디렉토리가 없다: $rows"
    reject_duplicate_units "$@"
    # HEAD 축과 기준선 축은 둘 다 일회용 트리다 — 브랜치에 붙은 작업 트리에서는 돌리지 않는다(R11).
    git -C "$w" rev-parse --git-dir >/dev/null 2>&1 || die "git 트리가 아니다: $w"
    if git -C "$w" symbolic-ref -q HEAD >/dev/null 2>&1; then
      die "브랜치에 붙은 트리에서는 돌리지 않는다 — create-baseline/create-head 가 만든 detached 트리를 넘겨라: $w"
    fi
    # 인자는 그 worktree 의 최상위여야 한다 — 하위 디렉토리에서는 git-dir 이 절대, common-dir 이 상대로 나온다.
    top=$(git -C "$w" rev-parse --show-toplevel 2>/dev/null) || die "트리의 최상위를 읽지 못했다: $w"
    [[ "$(cd "$w" && pwd -P)" == "$(cd "$top" && pwd -P)" ]] || die "트리의 최상위 디렉토리를 넘겨라: $w"
    gd=$(cd "$w" && cd "$(git rev-parse --git-dir)" && pwd -P) || die "git-dir 을 정규화하지 못했다: $w"
    gcd=$(cd "$w" && cd "$(git rev-parse --git-common-dir)" && pwd -P) || die "git-common-dir 을 정규화하지 못했다: $w"
    [[ "$gd" != "$gcd" ]] || die "주 작업 트리에서는 돌리지 않는다 — 일회용 트리를 넘겨라: $w"
    commit=$(git -C "$w" rev-parse HEAD 2>/dev/null) || die "트리의 커밋을 읽지 못했다: $w"
    load_rows "$rows"
    if [[ ${#ROWS_UNIT[@]} -gt 0 || -n "$T_RUNNER" ]]; then
      [[ "$T_RUNNER" == "$runner" ]] || die "행 파일의 러너가 다르다(${T_RUNNER} ≠ $runner): $rows"
      [[ "$T_COMMIT" == "$commit" ]] || die "행 파일이 다른 트리의 것이다(${T_COMMIT} ≠ $commit): $rows"
    fi
    flaky_out=$T_FLAKY
    if [[ "$mode" == "flaky" ]]; then
      [[ "$T_FLAKY" == "0" ]] || die "flaky 재실행은 행 파일당 한 번이다(R15): $rows"
      flaky_out=1
    fi

    NEW_UNIT=(); NEW_LINE=()
    if ! adapter_usable "$w" "$runner"; then
      if [[ "$mode" != "flaky" ]]; then
        for u in "$@"; do NEW_UNIT+=("$u"); NEW_LINE+=("$u"$'\t'"unrun"$'\t'"-"$'\t'"$mode"); done
      fi
      write_rows "$rows" "$runner" "$commit" "$flaky_out"
      exit 3
    fi
    PY_ARGV=(python3)
    py_argv "$w"

    has_go_tests() {
      local d=$1 g
      for g in "$d"/*_test.go; do [[ -f "$g" ]] && return 0; done
      return 1
    }
    # file unit 은 트리 안의 일반 파일, package unit 은 *_test.go 가 있는 디렉토리여야 존재한다(R20 · R21).
    exists_unit() {
      case "$gran" in
        file)    unit_within_worktree "$w" "$1" && [[ -f "$w/$1" ]] ;;
        package) unit_within_worktree "$w" "$1" && [[ -d "$w/$1" ]] && has_go_tests "$w/$1" ;;
        bulk)    [[ "$1" == "BULK" ]] ;;
      esac
    }
    shell_unit_in_scope() {
      unit_within_worktree "$w" "$1" || return 1
      case "$1" in
        tests/*.sh|*/tests/*.sh) [[ -x "$w/$1" ]] ;;
        *) return 1 ;;
      esac
    }
    refused=""
    is_refused() { printf '%s\n' "$refused" | grep -qxF -- "$1"; }
    status_of_exit() {
      case "$1" in 0) echo pass ;; 1) echo fail ;; 127) echo unrun ;; *) echo error ;; esac
    }
    run_units() {
      local rc=0 u d b dotted
      local -a go_args
      case "$runner" in
        pytest)
          ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m pytest -p no:cacheprovider -q "$@" ) >&2 || rc=$? ;;
        unittest)
          for u in "$@"; do
            d=$(dirname -- "$u"); b=$(basename -- "$u")
            if [[ "$d" == "." || -f "$w/$d/__init__.py" ]]; then
              dotted="${u%.py}"; dotted=$(printf '%s' "$dotted" | tr '/' '.')
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m unittest "$dotted" ) >&2 || rc=$?
            else
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m unittest discover -s "$d" -p "$b" ) >&2 || rc=$?
            fi
          done ;;
        shell)
          for u in "$@"; do
            if ! shell_unit_in_scope "$u"; then
              echo "run-test-selection: 실행 거부: $u — shell 어댑터의 범위(tests/*.sh, 실행 비트) 밖" >&2
              refused="$refused
$u"
              continue
            fi
            ( cd "$w" && bash "$u" ) >&2 || rc=$?
          done ;;
        jest)
          ( cd "$w" && npx --no-install jest --cache=false --ci "$@" ) >&2 || rc=$? ;;
        vitest)
          ( cd "$w" && npx --no-install vitest run "$@" ) >&2 || rc=$? ;;
        go)
          # 모듈 모드에서 `./` 없는 패턴은 import 경로로 풀린다 — 디렉토리 패턴으로 넘긴다.
          go_args=()
          for u in "$@"; do
            case "$u" in
              .|./*) go_args+=("$u") ;;
              *)     go_args+=("./$u") ;;
            esac
          done
          ( cd "$w" && go test "${go_args[@]}" ) >&2 || rc=$? ;;
        cargo)
          # 빌드 산출물은 트리마다 따로 둔다 — 두 축이 같은 target 을 나누면 한쪽 빌드가 다른 쪽을 덮는다.
          ( cd "$w" && CARGO_TARGET_DIR="$(cargo_target_dir_for "$w")" cargo test ) >&2 || rc=$? ;;
        make)
          ( cd "$w" && make test ) >&2 || rc=$? ;;
        npm-script)
          ( cd "$w" && npm test ) >&2 || rc=$? ;;
      esac
      return $rc
    }
    row_mode=$mode
    [[ "$mode" == "flaky" ]] && row_mode=flaky
    add_row() {   # add_row <unit> <status> <exit>
      if [[ "$mode" == "flaky" ]]; then
        # flaky 재실행이 관측하지 못한 unit 은 원래 행을 지킨다(R15).
        case "$2" in pass|fail|error) ;; *) return 0 ;; esac
      fi
      NEW_UNIT+=("$1"); NEW_LINE+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$row_mode")
    }
    exec_mode=$mode
    [[ "$mode" == "flaky" ]] && exec_mode=per-unit
    if [[ "$exec_mode" == "bulk" ]]; then
      present=()
      for u in "$@"; do exists_unit "$u" && present+=("$u"); done
      if [[ ${#present[@]} -gt 0 ]]; then
        run_units "${present[@]}"; brc=$?
        bst=$(status_of_exit "$brc")
      fi
      for u in "$@"; do
        if is_refused "$u"; then add_row "$u" unrun -
        elif exists_unit "$u"; then add_row "$u" "$bst" "$brc"
        else add_row "$u" absent -; fi
      done
    else
      for u in "$@"; do
        if exists_unit "$u"; then
          run_units "$u"; urc=$?
          if is_refused "$u"; then add_row "$u" unrun -
          else add_row "$u" "$(status_of_exit "$urc")" "$urc"; fi
        else
          add_row "$u" absent -
        fi
      done
    fi
    write_rows "$rows" "$runner" "$commit" "$flaky_out"
    exit 0
    ;;
  unrun)
    [[ $# -ge 5 ]] || die "usage: unrun <rows-file> <runner> <commit|-> <unit>..."
    rows=$2; runner=$3; commit=$4; shift 4
    granularity_of "$runner" >/dev/null
    [[ "$commit" =~ $COMMIT_RE ]] || die "commit 은 전체 sha 또는 '-' 여야 한다: $commit"
    [[ -d "$(dirname -- "$rows")" ]] || die "행 파일의 디렉토리가 없다: $rows"
    reject_duplicate_units "$@"
    load_rows "$rows"
    if [[ ${#ROWS_UNIT[@]} -gt 0 || -n "$T_RUNNER" ]]; then
      [[ "$T_RUNNER" == "$runner" ]] || die "행 파일의 러너가 다르다(${T_RUNNER} ≠ $runner): $rows"
      [[ "$T_COMMIT" == "$commit" ]] || die "행 파일이 다른 커밋의 것이다(${T_COMMIT} ≠ $commit): $rows"
    fi
    NEW_UNIT=(); NEW_LINE=()
    for u in "$@"; do NEW_UNIT+=("$u"); NEW_LINE+=("$u"$'\t'"unrun"$'\t'"-"$'\t'"skip"); done
    write_rows "$rows" "$runner" "$commit" "$T_FLAKY"
    exit 0
    ;;
  pending)
    [[ $# -ge 3 ]] || die "usage: pending <rows-file> <unit>..."
    rows=$2; shift 2
    load_rows "$rows"
    for u in "$@"; do
      observed=0
      for ((i = 0; i < ${#ROWS_UNIT[@]}; i++)); do
        if [[ "${ROWS_UNIT[$i]}" == "$u" ]]; then
          st=$(printf '%s\n' "${ROWS_LINE[$i]}" | cut -f2)
          [[ "$st" != "unrun" ]] && observed=1
          break
        fi
      done
      [[ $observed -eq 1 ]] || printf '%s\n' "$u"
    done
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|granularity|assign|run|unrun|pending)"
    ;;
esac
