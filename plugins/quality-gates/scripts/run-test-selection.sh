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
    has_adapter() { printf '%s\n' "$adapters" | grep -qxF "$1"; }

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
    seen_files=""
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
        # detect 의 has_exec_shell_tests 와 **같은 스코프**여야 한다 (설계 §5.9:
        # "실행비트가 선 tests/*.sh"). 경로 제한 없이 실행비트만 보면 diff 에 섞여 온
        # scripts/deploy.sh 같은 비-테스트 스크립트를 테스트 unit 으로 주장하게 되고,
        # run 이 그것을 HEAD 와 기준선 양쪽에서 실행한다 — 설계가 금지한 추측 실행이다.
        case "$f" in
          tests/*.sh|*/tests/*.sh) [[ -x "$w/$f" ]] && claimed=shell ;;
        esac
      fi
      if [[ -z "$claimed" && -n "$js" ]]; then
        case "$f" in
          *.test.ts|*.test.tsx|*.test.js|*.test.jsx| \
          *.spec.*) claimed="$js" ;;
        esac
      fi

      if [[ -n "$claimed" ]]; then
        claimed_gran=$(granularity_of "$claimed") || die "unknown runner: $claimed"
        if [[ "$claimed_gran" == "package" ]]; then
          # 파일 → 패키지 디렉토리 축약은 **여기서** 일어난다. 오케스트레이터가
          # 이 변환을 수행하는 경로는 없다 (AC52) — 배정 입력은 언제나 파일 경로다.
          pkg=$(dirname "$f")
          if ! printf '%s\n' "$seen_pkgs" | grep -qxF "$pkg"; then
            printf '%s\t%s\tpackage\n' "$pkg" "$claimed"
            seen_pkgs="$seen_pkgs
$pkg"
          fi
        else
          # file 축약도 package 와 같은 규칙: 중복 stdin 입력은 한 unit 행으로
          # 수렴한다 — diff-test-results.py 는 중복 unit 행을 exit 4(사용 오류)로
          # 본다, 정당한 실행이 입력 중복만으로 죽어서는 안 된다.
          if ! printf '%s\n' "$seen_files" | grep -qxF "$f"; then
            printf '%s\t%s\tfile\n' "$f" "$claimed"
            seen_files="$seen_files
$f"
          fi
        fi
      elif [[ -n "$absorber" ]]; then
        residual=1
      else
        # 실행 수단이 없다. 조용히 버리지 않고 unclaimed로 표면화한다 —
        # 소비자(SKILL)가 이것을 `verification: degraded`로 라우팅한다 (AC53).
        # 여기도 같은 중복-수렴 규칙이 적용된다 (위 file 분기와 동일 사유).
        if ! printf '%s\n' "$seen_files" | grep -qxF "$f"; then
          printf '%s\tunclaimed\tfile\n' "$f"
          seen_files="$seen_files
$f"
        fi
      fi
    done

    [[ $residual -eq 1 ]] && printf 'BULK\t%s\tbulk\n' "$absorber"
    for r in $unused_bulk; do
      echo "run-test-selection: 미실행 러너: $r (bulk 잔여는 $absorber 가 흡수)" >&2
    done
    exit 0
    ;;
  cargo-target-dir)
    # read-only 내성: 이 워크트리에 쓸 CARGO_TARGET_DIR. 트리별 독립임을 밖에서
    # 검증할 수 있게 노출한다 (AC50/T47). 아무것도 실행하지 않는다.
    [[ $# -eq 2 ]] || die "usage: cargo-target-dir <worktree-abs>"
    printf '%s/.qg-cargo-target\n' "$2"
    exit 0
    ;;
  run)
    [[ $# -ge 4 ]] || die "usage: run <worktree-abs> <runner> <mode> <unit>..."
    w=$2; runner=$3; mode=$4; shift 4
    [[ -d "$w" ]] || die "not a directory: $w"
    case "$mode" in bulk|per-unit) ;; *) die "unknown mode: $mode (expected bulk|per-unit)" ;; esac
    # die() 는 $(...) 안에서 서브셸만 죽인다 — 캡처-후-체크가 없으면 상위 스크립트가
    # 빈 gran으로 계속 진행한다. <runner> 는 여기서 CLI 인자라 이 경로가 도달 가능하다
    # (Task 2 리뷰; detect 안 호출부는 도달 불가라 그때는 급하지 않았다).
    gran=$(granularity_of "$runner") || die "unknown runner: $runner"

    emit_all_unrun() { local u; for u in "$@"; do printf '%s\tunrun\t-\n' "$u"; done; }

    # 어댑터가 **이 트리에서** 쓸 수 있는가. HEAD 감지 결과를 기준선에 재사용하지
    # 않는다 — 인프라를 바꾸는 diff에서 spurious error가 회귀를 PRE_EXISTING으로
    # 은폐할 수 있다 (AC47). 재감지 비용보다 오귀속 비용이 크다.
    # -qxF: runner 는 CLI 인자다 — -qx 로 매칭하면 PATTERN(BRE)로 해석되어 "pyt.st" 같은
    # 입력이 "pytest" 를 정규식으로 오매치한다 (Task 3 리뷰에서 같은 등급의 결함이 assign
    # 의 dedup에서 실제로 재현됐다).
    if ! detect_set "$w" | grep -qxF "$runner"; then
      echo "run-test-selection: 어댑터 사용 불가: $runner (in $w)" >&2
      emit_all_unrun "$@"; exit 3
    fi

    # setup_cmd — 어댑터 소유. 기준선·HEAD 양측에서 **같은 명령**이 돈다 (AC41).
    # 문자열은 위 닫힌 표에서만 오므로 외부 입력이 아니다. gran이 이미 같은 닫힌
    # 러너 집합에서 성공했으므로 setup_cmd_of가 같은 이름으로 die 할 일은 없다.
    scmd=$(setup_cmd_of "$w" "$runner")
    if [[ "$scmd" != "-" ]]; then
      if ! ( cd "$w" && sh -c "$scmd" ) >&2 2>&1; then
        echo "run-test-selection: setup 실패: $scmd" >&2
        emit_all_unrun "$@"; exit 3
      fi
    fi

    exists_unit() {
      case "$gran" in
        file)    [[ -e "$w/$1" ]] ;;
        package) [[ -d "$w/$1" ]] ;;
        bulk)    [[ "$1" == "BULK" ]] ;;
      esac
    }

    # 실행 지점의 방어(defense in depth). assign 은 shell 소유를 tests/*.sh|*/tests/*.sh
    # + 실행비트로 스코프했다(Task 3) — 하지만 run 은 <unit>... 을 커맨드라인에서
    # 그대로 받으므로, assign 을 우회하는 호출자(또는 assign 의 미래 버그)가 여전히
    # 임의 경로를 넘길 수 있다. 실행이 실제로 일어나는 이 지점에서 같은 스코프를 다시
    # 검증한다 — 설계 §5.9 "임의 명령을 추측해 실행하지 않는다".
    shell_unit_in_scope() {
      case "$1" in
        tests/*.sh|*/tests/*.sh) [[ -x "$w/$1" ]] ;;
        *) return 1 ;;
      esac
    }
    refused_units=""
    is_refused() { printf '%s\n' "$refused_units" | grep -qxF "$1"; }

    # exit code만 읽는다 — 러너별 출력 파서 없이 8종 전부에 같은 코드가 적용된다.
    # 0=pass, 1=fail, 그 외=error. error는 §5.5에서 fail 축으로 접히므로 error/fail
    # 사이의 오분류는 귀속을 바꾸지 않는다 (라벨의 `(error)` 병기만 달라진다).
    status_of_exit() { case "$1" in 0) echo pass ;; 1) echo fail ;; *) echo error ;; esac; }

    run_units() {   # run_units <unit>... → 러너의 종료 코드
      local rc=0 u d b dotted
      case "$runner" in
        pytest)
          ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -p no:cacheprovider -q "$@" ) >&2 || rc=$? ;;
        unittest)
          for u in "$@"; do
            d=$(dirname "$u"); b=$(basename "$u")
            if [[ "$d" == "." || -f "$w/$d/__init__.py" ]]; then
              dotted="${u%.py}"; dotted=$(printf '%s' "$dotted" | tr '/' '.')
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest "$dotted" ) >&2 || rc=$?
            else
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$d" -p "$b" ) >&2 || rc=$?
            fi
          done ;;
        shell)
          for u in "$@"; do
            if ! shell_unit_in_scope "$u"; then
              echo "run-test-selection: 실행 거부: $u — shell 어댑터의 스코프(tests/*.sh, 실행비트) 밖" >&2
              refused_units="$refused_units
$u"
              continue
            fi
            # $w 를 인자로 넘긴다 — 셸 테스트가 자신이 도는 워크트리 루트를 알 수
            # 있게 하는 관례(다른 러너는 인터프리터/툴체인이 cwd로 이를 대체한다).
            ( cd "$w" && bash "$u" "$w" ) >&2 || rc=$?
          done ;;
        jest)
          ( cd "$w" && npx --no-install jest --cache=false --ci "$@" ) >&2 || rc=$? ;;
        vitest)
          ( cd "$w" && npx --no-install vitest run "$@" ) >&2 || rc=$? ;;
        go)
          ( cd "$w" && go test "$@" ) >&2 || rc=$? ;;
        cargo)
          # 빌드 산출물은 트리별 독립 (AC50). 다운로드 캐시(CARGO_HOME/registry)는
          # 내용주소라 공유해도 두 트리가 같은 바이트를 본다 — 기본 위치 그대로 둔다.
          ( cd "$w" && CARGO_TARGET_DIR="$w/.qg-cargo-target" cargo test ) >&2 || rc=$? ;;
        make)
          ( cd "$w" && make test ) >&2 || rc=$? ;;
        npm-script)
          ( cd "$w" && npm test ) >&2 || rc=$? ;;
      esac
      return $rc
    }

    # unit 인자를 그대로 순회한다 (총 함수: 입력 하나당 정확히 한 행).
    present_count=0
    for u in "$@"; do exists_unit "$u" && present_count=$((present_count + 1)); done
    if [[ $present_count -eq 0 ]]; then
      for u in "$@"; do printf '%s\tabsent\t-\n' "$u"; done
      exit 0
    fi

    if [[ "$mode" == "bulk" ]]; then
      present_units=""
      for u in "$@"; do exists_unit "$u" && present_units="$present_units $u"; done
      # shellcheck disable=SC2086  # unit 경로에 공백 없음 (git 경로 계약)
      run_units $present_units; bulk_rc=$?
      bulk_status=$(status_of_exit "$bulk_rc")
      for u in "$@"; do
        if is_refused "$u"; then printf '%s\tunrun\t-\n' "$u"
        elif exists_unit "$u"; then printf '%s\t%s\t%s\n' "$u" "$bulk_status" "$bulk_rc"
        else printf '%s\tabsent\t-\n' "$u"; fi
      done
    else
      for u in "$@"; do
        if exists_unit "$u"; then
          run_units "$u"; unit_rc=$?
          if is_refused "$u"; then printf '%s\tunrun\t-\n' "$u"
          else printf '%s\t%s\t%s\n' "$u" "$(status_of_exit "$unit_rc")" "$unit_rc"; fi
        else
          printf '%s\tabsent\t-\n' "$u"
        fi
      done
    fi
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|assign|run)"
    ;;
esac
