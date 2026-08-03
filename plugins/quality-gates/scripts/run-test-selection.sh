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

# cargo 빌드 산출물의 트리-로컬 경로 — **유일 소유자**. cargo-target-dir 서브커맨드와
# run 의 cargo 실행 분기가 각자 리터럴을 들고 있으면 한쪽만 편집됐을 때 AC50이 조용히
# 깨진다 (기준선이 HEAD 산출물을 재사용). 반드시 이 함수를 통해서만 쓴다.
#
# 이름이 `target` 인 것이 계약의 일부다. cargo 의 기본 target 디렉토리가 이미
# 워크트리-로컬(`<트리>/target`)이라 AC50/M23 의 트리별 독립은 그대로 성립하고,
# **모든 실물 Rust 레포가 `/target` 을 gitignore 한다** (`cargo new` 가 그렇게 쓴다).
# qg 가 발명한 이름(`.qg-cargo-target` 등)을 쓰면 어떤 레포의 .gitignore 도 그것을
# 덮지 않으므로 빌드 산출물 전량이 untracked-and-unignored 가 되고, R7 의
# mutation-guard 가 그것을 `disallowed_new_files` → `forced_downgrade: yes` →
# **어떤 것으로도 downgrade 되지 않는 terminal FAIL** 로 만든다 (SKILL.md verdict
# 총순서). cargo 는 CARGO_TARGET_DIR 안에 .gitignore 를 쓰지 않으므로 구제책도 없다
# (실측: 실물 cargo 로 68 파일 staged). 이름을 바꾸려면 그 레포가 그 이름을 무시한다는
# 보장을 먼저 만들 것.
cargo_target_dir_for() { printf '%s/target\n' "$1"; }

# unit 경로가 워크트리 **안에** 있는가 — 부분문자열 검사가 아니라 담김(containment)
# 검사다. `../other/tests/evil.sh` 는 `*/tests/*.sh` 글롭과 `-x "$w/$f"` 를 **둘 다**
# 만족한다 (글롭은 담김을 검사하지 않는다). 그러면 assign 이 그것을 shell unit 으로
# 주장하고 run 이 `cd "$w" && bash "$u"` 로 워크트리 밖 스크립트를 실행한다 — 게다가
# 양측이 같은 unit 목록을 돌므로 **두 번** 실행된다. 실측으로 재현된 경로이며, 설계
# §5.9 의 "임의 명령을 추측해 실행하지 않는다" 를 정면으로 깬다.
unit_within_worktree() {   # unit_within_worktree <worktree> <unit>
  local w=$1 u=$2 root d
  case "$u" in
    /*)                            return 1 ;;   # 절대경로
    ..|../*|*/../*|*/..)           return 1 ;;   # `..` 성분
  esac
  root=$(cd "$w" 2>/dev/null && pwd -P) || return 1
  d=$(cd "$w/$(dirname "$u")" 2>/dev/null && pwd -P) || return 1
  # 심볼릭 링크까지 해소한 뒤 접두 비교 — 트리 밖을 가리키는 링크도 여기서 걸린다.
  case "$d" in
    "$root"|"$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# `.venv` 가 이 트리에서 git-ignored 인가. 어댑터가 트리 안에 만드는 환경 디렉토리가
# 그 레포의 .gitignore 로 덮이지 않으면 mutation-guard 가 전량을
# `disallowed_new_files` 로 잡아 terminal FAIL 을 낸다 — cargo target 과 같은 클래스다.
# 비-git 트리(테스트 픽스처)는 guard 대상이 아니므로 안전으로 본다.
venv_dir_is_ignored() {   # venv_dir_is_ignored <worktree>
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$1" check-ignore -q .venv 2>/dev/null
}

# 이 트리의 파이썬 실행 환경 — **setup_cmd 와 run 의 인터프리터가 같은 곳에서 온다**.
# 둘이 각자 판단하면 설치는 A 에, 실행은 B 에서 일어나 setup 이 실행에 대해 no-op 이
# 된다 (uv/poetry 레포에서 실제로 그랬다: setup 은 `uv sync`, 실행은 앰비언트
# `python3 -m pytest`). 토큰: uv | poetry | venv | ambient.
#
# uv 와 venv 는 트리 안에 `.venv` 를 만들므로 그 디렉토리가 ignored 일 때만 고른다.
# 아니면 ambient 로 떨어지고, 그때 러너를 못 쓰면 아래 가용성 프로브가 exit 3 로
# 정직하게 degrade 한다 (§5.10 row 3) — terminal FAIL 을 내는 것보다 낫다.
# poetry 의 기본 venv 는 트리 밖(`~/.cache/pypoetry/virtualenvs/<name>-<경로해시>`)이라
# 트리별로 이미 분리되고 트리 안에 아무것도 남기지 않는다 — 그래서 게이트가 없다.
python_env_of() {   # python_env_of <worktree>
  local w=$1
  if   [[ -f "$w/uv.lock"          ]] && venv_dir_is_ignored "$w"; then echo uv
  elif [[ -f "$w/poetry.lock"      ]]; then echo poetry
  elif [[ -f "$w/requirements.txt" ]] && venv_dir_is_ignored "$w"; then echo venv
  else echo ambient; fi
}

# run 이 쓸 파이썬 인터프리터 argv (워크트리 안에서 실행되는 것을 전제로 한 상대경로).
# 배열로 돌려주는 이유는 `uv run python` 처럼 여러 단어이기 때문이다 — 문자열로 두고
# 인용 없이 펼치면 경로에 공백이 든 트리에서 쪼개진다.
py_argv() {   # py_argv <worktree> → PY_ARGV 배열 설정
  case "$(python_env_of "$1")" in
    uv)     PY_ARGV=(uv run python) ;;
    poetry) PY_ARGV=(poetry run python) ;;
    venv)   PY_ARGV=(.venv/bin/python) ;;
    *)      PY_ARGV=(python3) ;;
  esac
}

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
  # `pytest-cov` / `pytest-mock` 만 선언하고 bare `pytest` 는 없는 레포도 pytest 레포다
  # (플러그인이 pytest 를 끌어온다). 그 신호를 놓치면 unittest 로 새고, unittest 아래서
  # 모듈-레벨 bare `def test_…` 함수는 **0개 수집 + exit 0** 으로 조용히 통과한다 —
  # 도구 부재(exit 127)보다 나쁜 실패다. 초록 exit 라 어떤 degrade 신호도 안 뜬다.
  # 그래서 뒤따르는 `-<plugin>` 을 허용한다. 앞의 경계는 그대로 둔다 (`mypytest` 같은
  # 접두 오탐 방지). 삽입한 `(-[a-z0-9]+)*` 는 빈 매치를 허용하므로 이 정규식은 옛
  # 정규식의 **엄격한 상위집합**이다 — 기존에 잡히던 것이 빠지는 경우가 없다.
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

setup_cmd_of() {   # setup_cmd_of <worktree> <runner>
  local w=$1
  case "$2" in
    pytest|unittest)
      # 설치처와 실행처는 python_env_of 하나에서 갈라진다 (py_argv 와 같은 소스).
      # `python3 -m pip install` 로 앰비언트에 설치하던 옛 분기는 제거됐다 — 그것은
      # 샌드박스 밖(사용자의 system/user site-packages)을 바꾸는 머신-레벨 부작용이고,
      # 기준선과 HEAD 가 **한 패키지 집합을 공유**하게 만들어 §5.4 가 옵션 ②를 기각한
      # 바로 그 hybrid 오염을 뒷문으로 들인다.
      case "$(python_env_of "$w")" in
        uv)     echo 'uv sync --frozen' ;;
        poetry) echo 'poetry install --no-interaction' ;;
        venv)   echo 'python3 -m venv .venv && .venv/bin/python -m pip install -q -r requirements.txt' ;;
        *)      echo '-' ;;
      esac ;;
    jest|vitest|npm-script)
      # `--no-package-lock`: 락파일 없는 레포에 `npm install` 을 돌리면 npm 이
      # package-lock.json 을 **새로 만든다**. 그런 레포는 정의상 그것을 gitignore 하지
      # 않으므로 mutation-guard 가 `disallowed_new_files` 로 잡아 terminal FAIL 이 된다
      # (cargo target 과 같은 클래스). 설치는 하되 트리에 새 파일을 남기지 않는다.
      if   [[ -f "$w/pnpm-lock.yaml"    ]]; then echo 'pnpm install --frozen-lockfile'
      elif [[ -f "$w/yarn.lock"         ]]; then echo 'yarn install --frozen-lockfile'
      elif [[ -f "$w/package-lock.json" ]]; then echo 'npm ci'
      else echo 'npm install --no-audit --no-fund --no-package-lock'; fi ;;
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
        # 담김 검사가 글롭과 **함께** 있어야 한다: `../other/tests/evil.sh` 는
        # `*/tests/*.sh` 와 `-x` 를 둘 다 만족하지만 이 워크트리 밖이다 (I5 실측).
        case "$f" in
          tests/*.sh|*/tests/*.sh)
            unit_within_worktree "$w" "$f" && [[ -x "$w/$f" ]] && claimed=shell ;;
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
    cargo_target_dir_for "$2"
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
      # 순서 주의: >&2 로 fd1 을 먼저 고정한 뒤 2>&1 은 no-op dup — 단순화 금지
      if ! ( cd "$w" && sh -c "$scmd" ) >&2 2>&1; then
        echo "run-test-selection: setup 실패: $scmd" >&2
        emit_all_unrun "$@"; exit 3
      fi
    fi

    # ── 실행-시점 가용성 프로브 ───────────────────────────────────────────────
    # detect_set 이 답하는 것은 *이 레포가 무엇을 선언했는가* 다 (go.mod 가 있다,
    # Cargo.toml 이 있다). 그 계약은 옳고 그대로 둔다 — 앰비언트 인터프리터로 감지하면
    # 같은 레포가 머신마다 다르게 감지된다 (case_no_ambient_pytest_probe 가 잠근 계약).
    #
    # 하지만 **선언 ≠ 설치**다. Go 를 선언했는데 toolchain 이 없는 머신에서는 `go test`
    # 가 exit 127 을 내고, status_of_exit 가 그것을 `error` 로, §5.5 가 `error` 를 fail
    # 축으로 접어 양측 fail → `PRE_EXISTING` → `attribution_status: closed` +
    # verdict_input 3키 전부 false → SKILL.md 의 **PASS 행이 테스트 0개로 충족**된다
    # (실측). 설계 §5.10 row 3 · AC34 · AC44 가 약속한 것의 정반대이며, shipped 코드에서
    # exit 3 은 러너 이름이 detect_set 에 없을 때만 도달 가능했다 — 즉 exit 3 이
    # 명세된 바로 그 상황(도구 부재)에서 사실상 절대 발동하지 않았다.
    #
    # 그래서 실행 **직전에** 도구 가용성을 따로 찌른다. setup_cmd 뒤에 두는 것이 중요하다
    # — uv/poetry/venv setup 이 바로 그 러너를 설치하기 때문이다. 부재면 이미 존재하는
    # exit 3 경로(emit_all_unrun + exit 3)로 보낸다: 하류 전체가 이미 올바르게 처리한다.
    runner_available() {   # runner_available <runner> → 0 = 이 트리에서 지금 실행 가능
      case "$1" in
        shell)       command -v bash  >/dev/null 2>&1 ;;
        go)          command -v go    >/dev/null 2>&1 ;;
        cargo)       command -v cargo >/dev/null 2>&1 ;;
        make)        command -v make  >/dev/null 2>&1 ;;
        npm-script)  command -v npm   >/dev/null 2>&1 ;;
        jest|vitest) command -v npx >/dev/null 2>&1 \
                       && ( cd "$w" && npx --no-install "$1" --version ) >/dev/null 2>&1 ;;
        # `-m pytest --version` 은 실행에 쓰는 것과 **같은 호출 형태**를 찌른다.
        pytest)      ( cd "$w" && "${PY_ARGV[@]}" -m pytest --version ) >/dev/null 2>&1 ;;
        # unittest 는 표준 라이브러리다 — 실질 질문은 인터프리터가 뜨는가이다.
        unittest)    ( cd "$w" && "${PY_ARGV[@]}" -c '' ) >/dev/null 2>&1 ;;
        *)           return 1 ;;
      esac
    }
    PY_ARGV=(python3)
    py_argv "$w"
    if ! runner_available "$runner"; then
      echo "run-test-selection: 러너 실행 불가: $runner — 도구가 이 머신에 없습니다 (in $w)" >&2
      emit_all_unrun "$@"; exit 3
    fi

    exists_unit() {
      case "$gran" in
        # 담김 검사가 존재 검사와 **함께** 있어야 한다. `../other/test_x.py` 는
        # `-e "$w/$1"` 을 만족하지만 이 워크트리 밖이고, 그대로 러너에 넘어가면
        # pytest/jest 가 워크트리 밖 코드를 실행한다 (shell 과 같은 클래스).
        # 워크트리 밖 unit 은 정의상 "이 트리에 없다" = `absent` 다.
        file)    unit_within_worktree "$w" "$1" && [[ -e "$w/$1" ]] ;;
        package) unit_within_worktree "$w" "$1" && [[ -d "$w/$1" ]] ;;
        bulk)    [[ "$1" == "BULK" ]] ;;
      esac
    }

    # 실행 지점의 방어(defense in depth). assign 은 shell 소유를 tests/*.sh|*/tests/*.sh
    # + 실행비트로 스코프했다(Task 3) — 하지만 run 은 <unit>... 을 커맨드라인에서
    # 그대로 받으므로, assign 을 우회하는 호출자(또는 assign 의 미래 버그)가 여전히
    # 임의 경로를 넘길 수 있다. 실행이 실제로 일어나는 이 지점에서 같은 스코프를 다시
    # 검증한다 — 설계 §5.9 "임의 명령을 추측해 실행하지 않는다".
    #
    # 글롭만으로는 부족하다: `../other/tests/evil.sh` 가 `*/tests/*.sh` 와 `-x` 를 둘 다
    # 만족한다 (I5 실측 — `cd "$w" && bash "$u"` 가 워크트리 밖 스크립트를 실행했고,
    # 양측이 같은 unit 목록을 돌므로 두 번 실행됐다). 담김을 명시적으로 검사한다.
    shell_unit_in_scope() {
      unit_within_worktree "$w" "$1" || return 1
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
    #
    # **127 = command not found 는 예외다.** error 로 두면 fail 축으로 접혀 양측
    # `PRE_EXISTING` → PASS 가 된다 — 위 가용성 프로브가 막는 바로 그 결과다. 프로브는
    # 실행 *직전*만 보므로, 실행 *도중* 사라지거나 러너가 부르는 하위 도구가 없는 경우는
    # 여기서 백스톱한다. `unrun` 은 미실행 축이라 SILENT_DROP/BASELINE_UNRUNNABLE 로 가고
    # 캐시에도 기록되지 않는다 (AC40) — 복구 가능한 환경 실패를 영구화하지 않는다.
    status_of_exit() { case "$1" in 0) echo pass ;; 1) echo fail ;; 127) echo unrun ;; *) echo error ;; esac; }

    run_units() {   # run_units <unit>... → 러너의 종료 코드
      local rc=0 u d b dotted
      case "$runner" in
        # `"${PY_ARGV[@]}"` = py_argv 가 python_env_of 에서 파생한 인터프리터 —
        # setup_cmd 가 준비한 **바로 그 환경**이다. 여기서 앰비언트 `python3` 를 쓰면
        # uv/poetry/venv 레포에서 setup 이 실행에 대해 no-op 이 되고, 그 실행은 다시
        # 위 exit-127/error 버킷으로 떨어진다 (I3).
        pytest)
          ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m pytest -p no:cacheprovider -q "$@" ) >&2 || rc=$? ;;
        unittest)
          for u in "$@"; do
            d=$(dirname "$u"); b=$(basename "$u")
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
              echo "run-test-selection: 실행 거부: $u — shell 어댑터의 스코프(tests/*.sh, 실행비트) 밖" >&2
              refused_units="$refused_units
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
          ( cd "$w" && go test "$@" ) >&2 || rc=$? ;;
        cargo)
          # 빌드 산출물은 트리별 독립 (AC50). 다운로드 캐시(CARGO_HOME/registry)는
          # 내용주소라 공유해도 두 트리가 같은 바이트를 본다 — 기본 위치 그대로 둔다.
          # cargo-target-dir 서브커맨드와 같은 함수(cargo_target_dir_for)로 계산한다 —
          # 두 리터럴로 흩어지면 한쪽만 편집됐을 때 AC50이 조용히 깨진다.
          ( cd "$w" && CARGO_TARGET_DIR="$(cargo_target_dir_for "$w")" cargo test ) >&2 || rc=$? ;;
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
      # 배열로 모은다 — 공백-연결 문자열을 그대로 펼치면(unquoted word-splitting) 경로에
      # 공백이 든 unit이 여러 위치 인자로 쪼개져 러너에 전달된다. git 경로는 공백을
      # 금지하지 않으므로 "경로에 공백 없음" 은 성립하지 않는 가정이었다 — 배열이 유일한
      # 안전한 형태다. present_count > 0 이 위에서 이미 보장되므로 빈 배열을
      # set -u 아래서 펼치는 문제도 없다.
      present_units=()
      for u in "$@"; do exists_unit "$u" && present_units+=("$u"); done
      run_units "${present_units[@]}"; bulk_rc=$?
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
