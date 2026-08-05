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
#
# **검사하는 축을 정확히 적는다** (이 주석은 두 번 실제보다 넓게 주장했고, 두 번 다 그
# 틈으로 탈출이 났다 — 라운드 2 NEW-2, 라운드 3 F1):
#
#   1. 렉시컬 — 절대경로, `..` 성분.
#   2. 경로의 **디렉토리 성분** — `pwd -P` 가 중간 심볼릭 링크를 전부 해소한다.
#   3. **잎이 심볼릭 링크일 때** 그 체인의 최종 대상 — 대상이 디렉토리면 대상 자신을,
#      파일이면 그 dirname 을 정규화한다.
#
# 여기서 판정하지 **않는** 것: 대상이 트리 안이지만 워크트리 루트/디렉토리인 경우.
# 그것은 담김 위반이 아니라 입도 위반이며 `exists_unit` 의 `-f` 가 막는다.
resolve_leaf_dir() {   # resolve_leaf_dir <abs-path> → 최종 대상의 정규화 위치 (pwd -P)
  # 체인을 직접 따라간다 — `readlink -f`/`realpath` 는 macOS 구버전에 없거나 다르게
  # 동작한다. 홉 상한은 순환 링크 방어이고, 상한 초과는 fail-closed(거부)다.
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
  # **대상이 디렉토리면 대상 자신을 정규화한다.** dirname 만 정규화하면 `..` 로 끝나는
  # 대상(`-> ../..`)이 새어나간다: 그 dirname 은 트리 **안**으로 정규화되는데 대상 자신은
  # 트리 밖이다. 실측 — `tests/evil.py -> ../..` 가 담김 검사를 통과했고 pytest 가 워크트리
  # **밖에서** 32개 테스트를 돌렸다(라운드 3 F1). 파일 대상은 basename 이 경로를 이동시킬
  # 수 없으므로 dirname 정규화로 충분하다.
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd -P) || return 1
  else
    (cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
  fi
}

unit_within_worktree() {   # unit_within_worktree <worktree> <unit>
  local w=$1 u=$2 root d leaf
  case "$u" in
    /*)                            return 1 ;;   # 절대경로
    ..|../*|*/../*|*/..)           return 1 ;;   # `..` 성분
  esac
  root=$(cd "$w" 2>/dev/null && pwd -P) || return 1
  # 1) 디렉토리 성분 — `pwd -P` 가 경로 중간의 심볼릭 링크를 전부 해소한다.
  #
  # **해소 실패(=경로가 이 트리에 없음)는 "트리 밖"이 아니다.** assign 은 그 트리에
  # 존재하지 않는 후보 경로도 받는다 — 기준선 트리에 아직 없는 신규 테스트, 다른
  # 어댑터가 가져갈 소스 파일 등. 부재를 담김 위반으로 승격하면 정당한 unit 이 조용히
  # `unclaimed` 가 되어 verification 이 이유 없이 degraded 된다(실측: 이 스위트의
  # case_assign_bulk_conflict·case_assign_spec_any_extension 가 즉시 RED 였다).
  # 위의 렉시컬 검사(절대경로·`..` 성분)가 이미 끝났고, 존재하지 않는 경로는 하류의
  # `-e`/`-x` 검사에서 `absent`/미주장으로 걸러지므로 여기서 통과시켜도 실행되지 않는다.
  d=$(cd "$w/$(dirname "$u")" 2>/dev/null && pwd -P) || return 0
  case "$d" in
    "$root"|"$root"/*) ;;
    *) return 1 ;;
  esac
  # 2) 잎 — 위 검사가 보지 못하는 축이다. 링크가 아니면 비용 0.
  if [[ -L "$w/$u" ]]; then
    leaf=$(resolve_leaf_dir "$w/$u") || return 1
    case "$leaf" in
      "$root"|"$root"/*) ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

# <dir> 가 이 트리에서 git-ignored 인가.
#
# **반드시 후행 슬래시로 질의한다.** `.gitignore` 의 디렉토리 전용 패턴(`.venv/`,
# `**/.venv/`, `/.venv/`)은 **아직 존재하지 않는** 경로에 대해 `check-ignore .venv` 로는
# 매치되지 않는다 — 그리고 프로덕션은 언제나 부재 상태로 질의한다(기준선 워크트리는 갓
# 만들어지고, create-sandbox 는 git-ignored 파일을 일부러 제외한다). 같은 레포·같은
# `.gitignore` 인데 디렉토리 유무로 답이 갈리는 **상태 의존** 질의이기도 했다.
# 실측 (git 2.50.1) — 후행 슬래시 질의는 다섯 형태 전부에 매치된다:
#
#   패턴        `.venv` 질의   `.venv/` 질의
#   .venv           0              0
#   .venv/          1              0        ← 정상 레포가 여기서 조용히 새어나갔다
#   **/.venv/       1              0
#   /.venv/         1              0
#   .venv*          0              0
#
# 비-git 트리(테스트 픽스처)는 mutation-guard 대상이 아니므로 안전으로 본다.
dir_is_ignored() {   # dir_is_ignored <worktree> <dir-name>
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$1" check-ignore -q "$2/" 2>/dev/null
}

# 어댑터의 setup 이 이 트리 **안에** 만드는 환경 디렉토리 (없으면 빈 문자열).
# 이것이 그 레포의 .gitignore 로 덮이지 않으면 R7 mutation-guard 가 전량을
# `disallowed_new_files` 로 잡아 terminal FAIL 을 낸다 — cargo target 과 같은 클래스다.
# poetry 의 기본 venv 는 트리 밖(`~/.cache/pypoetry/virtualenvs/<name>-<경로해시>`)이라
# 트리별로 이미 분리되고 트리 안에 아무것도 남기지 않는다 — 그래서 빈 문자열이다.
setup_env_dir_of() {   # setup_env_dir_of <worktree> <runner>
  case "$2" in
    pytest|unittest)
      case "$(python_env_of "$1")" in uv|venv) echo .venv ;; *) echo "" ;; esac ;;
    jest|vitest|npm-script) echo node_modules ;;
    *) echo "" ;;
  esac
}

# 이 트리의 파이썬 실행 환경 — **setup_cmd 와 run 의 인터프리터가 같은 곳에서 온다**.
# 둘이 각자 판단하면 설치는 A 에, 실행은 B 에서 일어나 setup 이 실행에 대해 no-op 이
# 된다 (uv/poetry 레포에서 실제로 그랬다: setup 은 `uv sync`, 실행은 앰비언트
# `python3 -m pytest`). 토큰: uv | poetry | venv | ambient.
#
# **여기서 ignore 상태를 보지 않는다.** 한때 `.venv` 가 ignored 일 때만 uv/venv 를 골랐는데,
# 그러면 아닌 레포에서 setup_cmd 가 조용히 `-` 로 내려가고, 준비 안 된 실행이 양측에서
# 똑같이 실패해 `error → PRE_EXISTING → closed` = **테스트 0개 PASS** 가 된다 — C2 가
# 죽이려던 바로 그 verdict 행을 다른 문으로 되살린 것이다. 게이트는 아래 run 에서
# **어댑터를 못 쓴다고 선언**(exit 3)하는 형태로만 존재한다. 부수적으로 setup_cmd 가
# `.gitignore` 내용에 의존하지 않게 되어 AC41 의 양측 동일성도 더 견고해진다.
python_env_of() {   # python_env_of <worktree>
  local w=$1
  if   [[ -f "$w/uv.lock"          ]]; then echo uv
  elif [[ -f "$w/poetry.lock"      ]]; then echo poetry
  elif [[ -f "$w/requirements.txt" ]]; then echo venv
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
# unittest 어댑터가 이 파일을 **판정할 수 있는가**.
#
# 모듈-레벨 bare `def test_…` 만 있는 pytest 스타일 파일은 `unittest discover` 가 0개를
# 수집하고 **exit 0** 을 낸다 — 아무것도 판정하지 않았는데 `pass` 행이 서고, 양측 동일
# 하면 STILL_GREEN → 테스트 0개로 PASS 다. 위 repo_declares_pytest 주석이 이 실패를
# 정확히 이름 붙였지만 적용된 수정은 **감지**만 넓혔고 어댑터는 그대로였다. 그래서
# "pytest 를 어디에도 선언하지 않은 레포" 라는 잔여 경로가 남아 있었다.
#
# 종료 코드로는 구분할 수 없으므로(실측: 0개 수집도 exit 0) **선택 시점에** 거른다 —
# 설계의 "exit code 만 읽는다, 러너별 출력 파서 없이" 규약을 지키는 유일한 지점이다.
# 오분류 방향도 옳다: 못 고르면 `unclaimed` → SKILL.md 가 verification 을 degraded 로
# 보내 PASS 가 불가능해진다. 조용한 초록보다 시끄러운 degrade 가 낫다.
#
# `TestCase` 도 신호로 받는다 — `from django.test import TestCase` 처럼 unittest 를
# 직접 import 하지 않지만 discover 가 정상 수집하는 형태가 있다.
unittest_can_judge() {   # unittest_can_judge <worktree> <relpath> → 0 = 판정 가능
  grep -qE '(unittest|TestCase)' "$1/$2" 2>/dev/null
}

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
      # 워크트리 밖 경로는 **어떤 어댑터의 소유도 아니다** — 이 트리의 unit 이 아니기
      # 때문이다. 러너별 분기 안이 아니라 여기서 한 번에 거른다: 원래 결함은 shell 글롭이
      # 담김을 검사하지 않는 것이었지만, pytest/jest 분기도 같은 축으로 열려 있었다.
      # bulk 흡수자에게 넘기지도 않는다 — 흡수는 그 사실을 감춘다. `unclaimed` 로
      # 표면화해 `verification: degraded` → PASS 불가로 보낸다 (AC53).
      if ! unit_within_worktree "$w" "$f"; then
        if ! printf '%s\n' "$seen_files" | grep -qxF "$f"; then
          printf '%s\tunclaimed\tfile\n' "$f"
          seen_files="$seen_files
$f"
        fi
        continue
      fi
      claimed=""
      # 파일 패턴 소유권. 순서는 §5.9 표 순서 — 한 파일은 정확히 한 어댑터에 간다 (AC46).
      case "$f" in
        *_test.go) has_adapter go && claimed=go ;;
      esac
      if [[ -z "$claimed" && -n "$py" ]]; then
        case "$f" in test_*.py|*/test_*.py|*_test.py) claimed="$py" ;; esac
        # unittest 는 **판정할 수 없는 파일을 claim 하지 않는다** (unittest_can_judge).
        # pytest 어댑터에는 적용하지 않는다 — pytest 는 bare `def test_` 를 정상 수집하고,
        # 수집 0개일 때 exit 5 를 내므로 did_not_run_code 표가 이미 잡는다.
        if [[ "$claimed" == "unittest" ]] && ! unittest_can_judge "$w" "$f"; then
          claimed=""
        fi
      fi
      if [[ -z "$claimed" ]] && has_adapter shell; then
        # detect 의 has_exec_shell_tests 와 **같은 스코프**여야 한다 (설계 §5.9:
        # "실행비트가 선 tests/*.sh"). 경로 제한 없이 실행비트만 보면 diff 에 섞여 온
        # scripts/deploy.sh 같은 비-테스트 스크립트를 테스트 unit 으로 주장하게 되고,
        # run 이 그것을 HEAD 와 기준선 양쪽에서 실행한다 — 설계가 금지한 추측 실행이다.
        # 담김은 루프 머리에서 이미 걸렀다 (모든 어댑터 공통).
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

    # setup 이 이 트리 안에 만드는 환경 디렉토리(`.venv`·`node_modules`)를 그 레포가
    # gitignore 하지 않으면, 그대로 두면 R7 mutation-guard 가 그 전량을
    # `disallowed_new_files` 로 잡아 **어떤 것으로도 downgrade 되지 않는 terminal FAIL**
    # 을 낸다 (cargo target 과 같은 클래스).
    #
    # 그렇다고 setup 을 **조용히 건너뛰면 안 된다.** 준비 안 된 실행은 양측에서 똑같이
    # 실패하고, `error` 는 §5.5 에서 fail 축으로 접혀 `PRE_EXISTING → closed` 가 되며
    # 그것이 정확히 SKILL.md 의 PASS 행이다 — 테스트 0개로 PASS. C2 를 다른 문으로
    # 되살리는 경로이므로 명시적으로 막는다.
    #
    # 남는 정직한 선택지는 하나뿐이다: **이 어댑터는 이 트리에서 못 쓴다**고 선언한다.
    # exit 3 + 전 unit `unrun` → `verification: degraded` → PASS 불가 (§5.10 row 3).
    if [[ "$scmd" != "-" ]]; then
      env_dir=$(setup_env_dir_of "$w" "$runner")
      if [[ -n "$env_dir" ]] && ! dir_is_ignored "$w" "$env_dir"; then
        echo "run-test-selection: 어댑터 사용 불가: $runner — setup 이 만드는 '$env_dir/' 를 이 레포가 gitignore 하지 않습니다 (in $w). 설치하면 mutation-guard 가 terminal FAIL 을 내고, 설치를 건너뛰면 준비 안 된 실행이 PRE_EXISTING 으로 접혀 조용히 PASS 가 됩니다 — 미실행으로 degrade 합니다." >&2
        emit_all_unrun "$@"; exit 3
      fi
    fi

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

    has_go_tests() {   # has_go_tests <abs-dir> → 0 = *_test.go 가 하나라도 있다
      # nullglob 에 의존하지 않는다: 매치가 없으면 glob 이 리터럴로 남고 `-f` 가 거짓이라
      # 그대로 1 로 떨어진다. 셸 옵션 상태와 무관하게 같은 답을 낸다.
      local d=$1 g
      for g in "$d"/*_test.go; do [[ -f "$g" ]] && return 0; done
      return 1
    }

    exists_unit() {
      case "$gran" in
        # 담김 검사가 존재 검사와 **함께** 있어야 한다. `../other/test_x.py` 는
        # `-e "$w/$1"` 을 만족하지만 이 워크트리 밖이고, 그대로 러너에 넘어가면
        # pytest/jest 가 워크트리 밖 코드를 실행한다 (shell 과 같은 클래스).
        # 워크트리 밖 unit 은 정의상 "이 트리에 없다" = `absent` 다.
        #
        # `-e` 가 아니라 **`-f`**(일반 파일)인 이유: `granularity: file` 의 unit 은 설계
        # §5.4 표상 "테스트 파일 경로"다. 디렉토리가 file unit 으로 들어오면 러너가 그
        # 디렉토리 **전체**를 돌고 그 결과가 unit 하나의 `pass` 로 보고된다 — 귀속이
        # 파괴되는데 행은 초록이다. 트리 **안**을 가리키는 `tests/link.py -> ..` 는 담김
        # 검사를 정당하게 통과하므로(실제로 트리 안이다) 이 축은 여기서만 막을 수 있다.
        # `-f` 는 심볼릭 링크를 따라가므로 정당한 파일 링크는 그대로 통과한다.
        #
        # `package`(go 전용, granularity_of:177)는 `-d` **에 더해** 그 디렉토리에
        # `*_test.go` 가 하나라도 있을 것을 요구한다. `-d` 만 보면 테스트가 없는 패키지가
        # 존재로 판정되고 `go test ./pkg` 가 "no test files" 로 **exit 0** 을 내 `pass`
        # 행이 선다 — 아무것도 판정하지 않았는데 초록이다.
        # 이 경로는 실제로 도달한다: assign 은 `*_test.go` 만 claim 하지만(:373) 그
        # 패키지 unit 이 **기준선 트리**에서 실행될 때, 그 테스트 파일이 이번 diff 가
        # 추가한 것이면 merge_base 에는 없다. `absent` 로 떨어뜨리는 것이 정확하다 —
        # (A,F)=NEW_TEST_RED / (A,P)=NEW_TEST_GREEN 로 제대로 라벨된다.
        file)    unit_within_worktree "$w" "$1" && [[ -f "$w/$1" ]] ;;
        package) unit_within_worktree "$w" "$1" && [[ -d "$w/$1" ]] && has_go_tests "$w/$1" ;;
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
    # **판정하지 않은 실행은 pass 도 fail 도 아니다.** 예전에는 127 하나만 예외였는데,
    # 위 주석이 이름 붙인 실패 클래스("error 로 두면 fail 축으로 접혀 양측 PRE_EXISTING
    # → PASS")의 원소는 127 말고도 많다. /qg iter-1 에서 126·137 이 실측 재현됐다.
    # 여기 있는 코드는 전부 "러너가 테스트를 하나도 판정하지 못했다" 를 뜻한다.
    did_not_run_code() {   # did_not_run_code <runner> <exit> → 0 = 판정 안 함
      case "$2" in
        # 러너 무관 — 프로세스가 판정을 끝내지 못했다.
        #   126 실행 불가(퍼미션·셔뱅) · 127 명령 없음 · 124 GNU timeout
        #   137 SIGKILL(OOM 킬러) · 143 SIGTERM
        126|127|124|137|143) return 0 ;;
      esac
      case "$1" in
        # pytest 종료 코드(이 환경에서 실측): 0=pass 1=fail 2=중단 3=내부오류
        # 4=사용오류(잘못된 ini 옵션·없는 파일) 5=수집 0개. 2~5 는 전부 미판정이다.
        # 특히 5 는 "고른 파일에 테스트가 하나도 없다" 라 가장 조용한 초록을 만든다.
        pytest) case "$2" in 2|3|4|5) return 0 ;; esac ;;
        # go: 1 = 테스트 실패, **2 = 빌드/vet 실패**(컴파일 자체가 안 됨 → 테스트가 하나도
        # 돌지 않았다). adversarial 이 C2 의 형제 위치로 지목한 축이다.
        go)     case "$2" in 2) return 0 ;; esac ;;
      esac
      return 1
    }
    # cargo 의 101(테스트 실패)·make 의 2 등 러너 고유 실패 코드는 위 표에 **없다** —
    # 그것들은 판정을 했고 실패한 것이므로 아래 `*) error` 로 남는다(기존 동작 유지).
    status_of_exit() {
      if did_not_run_code "$runner" "$1"; then echo unrun; return; fi
      case "$1" in 0) echo pass ;; 1) echo fail ;; *) echo error ;; esac
    }

    run_units() {   # run_units <unit>... → 러너의 종료 코드
      local rc=0 u d b dotted
      local -a go_args
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
          # 모듈 모드에서 `.` 이나 `/` 로 시작하지 않는 패턴은 **import 경로**로 해석된다.
          # 그래서 `go test pkg/name` 은 module-local 패키지를 못 찾고
          # "package pkg/name is not in std" 로 **exit 1** 을 낸다 (실측). exit 1 은
          # `error` 도 아닌 `fail` 로 매핑되므로 가용성 프로브가 지키는 `unrun` 축에
          # 닿지도 못하고, 양측이 같은 행을 내 `PRE_EXISTING` → 테스트 0개로 PASS 가 된다.
          # 루트 unit `.` 은 이미 디렉토리 패턴이라 그대로 둔다.
          #
          # 접두를 assign 이 아니라 **여기서** 붙이는 이유: unit 문자열은 baseline 캐시의
          # 키이자 `--expected` 의 원소다. assign 에서 붙이면 키가 `./` 로 오염돼
          # repo-상대 평문이라는 계약이 깨진다 (AC52 — 어댑터 표의 유일 소유자는 이 파일).
          go_args=()
          for u in "$@"; do
            case "$u" in
              .|./*) go_args+=("$u") ;;
              *)     go_args+=("./$u") ;;
            esac
          done
          ( cd "$w" && go test "${go_args[@]}" ) >&2 || rc=$? ;;
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
