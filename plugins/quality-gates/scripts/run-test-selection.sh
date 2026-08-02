#!/usr/bin/env bash
# run-test-selection.sh — 결정론 테스트 러너 어댑터 표면 (design 2026-08-01 §5.4/§5.9).
#
#   detect <worktree-abs>                          → 어댑터 집합 (3줄 × N, 빈 줄 구분)
#   assign <worktree-abs>   < candidate-files      → <unit>\t<runner|unclaimed>\t<granularity>
#   run    <worktree-abs> <runner> <mode> <unit>…  → <unit>\t<status>\t<exit-code>  (총 함수)
#
# 이 스크립트는 어댑터 표의 **유일 소유자**다. 오케스트레이터가 감지 조건이나
# unit 변환을 재구현하는 경로는 없다 (AC38 / AC52).
#
# Exit: 0 = 정상 · 2 = 사용 오류 · 3 = 어댑터 사용 불가(run 전용, 전 unit `unrun` 동반)
set -u

die() { echo "run-test-selection: $*" >&2; exit 2; }

# ── 어댑터 표 (§5.9). 배열 순서 = 소유권 충돌 해소 순서이자 detect 출력 순서. ──
granularity_of() {
  case "$1" in
    pytest|unittest|shell|jest|vitest) echo file ;;
    go)                                echo package ;;
    cargo|make|npm-script)             echo bulk ;;
    *) die "unknown runner: $1" ;;
  esac
}

# package.json의 한 필드를 안전하게 읽는다. grep으로 JSON을 긁으면 description에
# 들어간 "jest" 같은 문자열이 오탐이 되므로 파서를 쓴다. python3 부재 시 실패(=미감지)로
# 떨어지는 것이 fail-closed 방향이다.
pkg_field() {   # pkg_field <worktree> <dotted.path> → 값 출력, 없으면 exit 1
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

has_pytest_config() {
  local w=$1
  [[ -f "$w/pytest.ini" ]] && return 0
  [[ -f "$w/tox.ini"    ]] && grep -q '^\[pytest\]'      "$w/tox.ini"    2>/dev/null && return 0
  [[ -f "$w/setup.cfg"  ]] && grep -q '^\[tool:pytest\]' "$w/setup.cfg"  2>/dev/null && return 0
  [[ -f "$w/pyproject.toml" ]] && grep -q '^\[tool\.pytest' "$w/pyproject.toml" 2>/dev/null && return 0
  return 1
}

# 이 **레포**가 pytest 를 쓰는가 — 이 **머신**에 pytest 가 깔렸는가가 아니다.
# 앰비언트 인터프리터 probe(호출부 python3 로 pytest 모듈 가용성을 직접 찔러보는 방식)는
# 두 질문을 뭉개서 같은 레포가 머신마다 다르게 감지되게 만든다. 선언은 레포 안에 있다.
repo_declares_pytest() {
  local w=$1
  # conftest.py 는 pytest 전용 파일이다 — 설정 섹션 없는 pytest 레포의 주된 신호.
  find "$w" -name .git -prune -o -type f -name 'conftest.py' -print 2>/dev/null | head -1 | grep -q . && return 0
  local f
  for f in requirements.txt requirements-dev.txt requirements/dev.txt pyproject.toml setup.cfg tox.ini; do
    [[ -f "$w/$f" ]] && grep -qiE '(^|[^a-z-])pytest([^a-z-]|$)' "$w/$f" 2>/dev/null && return 0
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

setup_cmd_of() {   # setup_cmd_of <worktree> <runner>
  local w=$1
  case "$2" in
    pytest|unittest)
      if   [[ -f "$w/uv.lock"          ]]; then echo 'uv sync --frozen'
      elif [[ -f "$w/poetry.lock"      ]]; then echo 'poetry install --no-interaction'
      elif [[ -f "$w/requirements.txt" ]]; then echo 'python3 -m pip install -q -r requirements.txt'
      else echo '-'; fi ;;
    jest|vitest|npm-script)
      if   [[ -f "$w/pnpm-lock.yaml"    ]]; then echo 'pnpm install --frozen-lockfile'
      elif [[ -f "$w/yarn.lock"         ]]; then echo 'yarn install --frozen-lockfile'
      elif [[ -f "$w/package-lock.json" ]]; then echo 'npm ci'
      else echo 'npm install --no-audit --no-fund'; fi ;;
    shell|go|cargo|make) echo '-' ;;
    *) die "unknown runner: $2" ;;
  esac
}

# detect_set <worktree> → 감지된 runner 이름을 표 순서대로 한 줄씩.
# 감지된 어댑터는 **모두** 반환한다 — 우선순위 1위만 고르면 폴리글랏 레포에서
# 나머지 러너의 테스트가 floor에서 조용히 누락된다 (AC45; 이 레포 실측: .sh 130개).
detect_set() {
  local w=$1 out=""
  # 파이썬: pytest 설정 > (pytest를 레포가 선언 + python 테스트 존재) > unittest. 상호배타 (AC54).
  if has_pytest_config "$w"; then
    out="$out pytest"
  elif has_python_tests "$w" && repo_declares_pytest "$w"; then
    out="$out pytest"
  elif has_python_tests "$w"; then
    out="$out unittest"
  fi

  has_exec_shell_tests "$w" && out="$out shell"

  # jest vs vitest: 둘 다 devDeps에 있으면 scripts.test가 호출하는 쪽.
  # 판별 불가면 **둘 다 버리고** npm-script로 폴백 — 잘못된 러너로 돌리느니
  # 그 프로젝트가 정의한 명령을 쓴다 (AC54).
  local has_jest=0 has_vitest=0 js_pick="" test_script=""
  pkg_field "$w" devDependencies.jest   >/dev/null 2>&1 && has_jest=1
  pkg_field "$w" devDependencies.vitest >/dev/null 2>&1 && has_vitest=1
  if [[ $has_jest -eq 1 && $has_vitest -eq 1 ]]; then
    test_script=$(pkg_field "$w" scripts.test 2>/dev/null || true)
    case "$test_script" in
      *vitest*) js_pick=vitest ;;
      *jest*)   js_pick=jest ;;
      *)        js_pick="" ;;
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

case "${1:-}" in
  detect)
    [[ $# -eq 2 ]] || die "usage: detect <worktree-abs>"
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
  assign)
    [[ $# -eq 2 ]] || die "usage: assign <worktree-abs>   # stdin: candidate file paths"
    w=$2
    [[ -d "$w" ]] || die "not a directory: $w"
    adapters=$(detect_set "$w")
    has_adapter() { printf '%s\n' "$adapters" | grep -qx "$1"; }

    # bulk 잔여 흡수자 = 표 순서상 첫 bulk 어댑터. 나머지는 감지됐어도 실행하지 않는다
    # — 같은 스위트를 두 번 돌리지 않기 위해서다 (AC54). 버리는 대신 loud하게 알린다.
    absorber=""; unused_bulk=""
    for r in cargo make npm-script; do
      if has_adapter "$r"; then
        if [[ -z "$absorber" ]]; then absorber="$r"; else unused_bulk="$unused_bulk $r"; fi
      fi
    done
    py=""; has_adapter pytest && py=pytest; has_adapter unittest && py=unittest
    js=""; has_adapter jest   && js=jest;   has_adapter vitest   && js=vitest

    residual=0
    seen_pkgs=""
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      claimed=""
      # 파일 패턴 소유권. 순서는 §5.9 표 순서 — 한 파일은 정확히 한 어댑터에 간다 (AC46).
      case "$f" in
        *_test.go) has_adapter go && claimed=go ;;
      esac
      if [[ -z "$claimed" && -n "$py" ]]; then
        case "$f" in test_*.py|*/test_*.py|*_test.py) claimed="$py" ;; esac
      fi
      if [[ -z "$claimed" ]] && has_adapter shell; then
        case "$f" in
          *.sh) [[ -x "$w/$f" ]] && claimed=shell ;;
        esac
      fi
      if [[ -z "$claimed" && -n "$js" ]]; then
        case "$f" in
          *.test.ts|*.test.tsx|*.test.js|*.test.jsx| \
          *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) claimed="$js" ;;
        esac
      fi

      if [[ -n "$claimed" ]]; then
        claimed_gran=$(granularity_of "$claimed") || die "unknown runner: $claimed"
        if [[ "$claimed_gran" == "package" ]]; then
          # 파일 → 패키지 디렉토리 축약은 **여기서** 일어난다. 오케스트레이터가
          # 이 변환을 수행하는 경로는 없다 (AC52) — 배정 입력은 언제나 파일 경로다.
          pkg=$(dirname "$f")
          if ! printf '%s\n' "$seen_pkgs" | grep -qx "$pkg"; then
            printf '%s\t%s\tpackage\n' "$pkg" "$claimed"
            seen_pkgs="$seen_pkgs
$pkg"
          fi
        else
          printf '%s\t%s\tfile\n' "$f" "$claimed"
        fi
      elif [[ -n "$absorber" ]]; then
        residual=1
      else
        # 실행 수단이 없다. 조용히 버리지 않고 unclaimed로 표면화한다 —
        # 소비자(SKILL)가 이것을 `verification: degraded`로 라우팅한다 (AC53).
        printf '%s\tunclaimed\tfile\n' "$f"
      fi
    done

    [[ $residual -eq 1 ]] && printf 'BULK\t%s\tbulk\n' "$absorber"
    for r in $unused_bulk; do
      echo "run-test-selection: 미실행 러너: $r (bulk 잔여는 $absorber 가 흡수)" >&2
    done
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|assign|run)"
    ;;
esac
