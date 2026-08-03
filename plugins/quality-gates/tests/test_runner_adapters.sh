#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh detect의 어댑터 8종 (design §5.9).
# AC34 AC38 AC45 AC56(detect) · T25 T34 T42 · M14 M20
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

TAB=$'\t'

PASS=0; FAIL=0; W=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
# setup_cmd_of <worktree> — detect 출력에서 setup_cmd 값만 뽑는다
setup_cmd_of_tree() { bash "$RTS" detect "$1" | awk '$1 == "setup_cmd:" { $1=""; sub(/^ /,""); print }'; }
# 인자를 기록하고 성공하는 스텁 실행파일 — 실물 toolchain 없이 실행 argv 를 관측한다
record_stub() {   # record_stub <path> <label> <observed-file>
  { printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s %%s\\n" %s "$*" >> %s\n' "$(printf '%q' "$2")" "$(printf '%q' "$3")"
    printf 'exit 0\n'
  } > "$1"
  chmod +x "$1"
}
mkw()  { W=$(mktemp -d) || exit 1; }
rmw()  { cd / && rm -rf "$W"; }
# runners <worktree> → 감지된 runner 이름을 개행으로
runners() { bash "$RTS" detect "$1" | awk '$1 == "runner:" { print $2 }'; }
gran_of() { bash "$RTS" detect "$1" | awk -v r="$2" '
  $1=="runner:"{cur=$2} $1=="granularity:" && cur==r {print $2}'; }

# T34/T25: 8 어댑터 각각 감지
case_pytest()   { mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "pytest" ]] && pass "pytest.ini → pytest" || fail "pytest ($(runners "$W"))"; rmw; }
case_unittest() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  [[ "$(runners "$W")" == "unittest" ]] && pass "설정 없는 test_*.py → unittest" || fail "unittest ($(runners "$W"))"; rmw; }
# 설정 섹션이 없어도 레포가 pytest 를 선언하면 pytest — 이 케이스가 없으면
# tier 2 가 죽은 코드인지 산 코드인지 스위트가 구분하지 못한다.
case_pytest_declared_without_config() {
  mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"; : > "$W/conftest.py"
  [[ "$(runners "$W")" == "pytest" ]] \
    && pass "conftest.py + test_*.py (설정 섹션 없음) → pytest" \
    || fail "tier2 conftest ($(runners "$W"))"
  rmw
}
case_shell()    { mkw; mkdir -p "$W/tests"; printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  [[ "$(runners "$W")" == "shell" ]] && pass "실행비트 tests/*.sh → shell" || fail "shell ($(runners "$W"))"; rmw; }
case_jest()     { mkw; printf '{"devDependencies":{"jest":"29"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "jest" ]] && pass "devDeps.jest → jest" || fail "jest ($(runners "$W"))"; rmw; }
case_vitest()   { mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "vitest" ]] && pass "devDeps.vitest → vitest" || fail "vitest ($(runners "$W"))"; rmw; }
case_go()       { mkw; printf 'module x\n' > "$W/go.mod"
  [[ "$(runners "$W")" == "go" && "$(gran_of "$W" go)" == "package" ]] \
    && pass "go.mod → go(package)" || fail "go ($(runners "$W"))"; rmw; }
case_cargo()    { mkw; printf '[package]\nname="x"\n' > "$W/Cargo.toml"
  [[ "$(runners "$W")" == "cargo" && "$(gran_of "$W" cargo)" == "bulk" ]] \
    && pass "Cargo.toml → cargo(bulk)" || fail "cargo ($(runners "$W"))"; rmw; }
case_make()     { mkw; printf 'test:\n\t@true\n' > "$W/Makefile"
  [[ "$(runners "$W")" == "make" ]] && pass "Makefile test: → make" || fail "make ($(runners "$W"))"; rmw; }
case_npmscript(){ mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  [[ "$(runners "$W")" == "npm-script" ]] && pass "scripts.test(비-jest/vitest) → npm-script" || fail "npm-script ($(runners "$W"))"; rmw; }

# T54(detect 절반) + AC56: 감지 0개 → 빈 stdout + exit 0
case_zero_adapters() {
  mkw; : > "$W/README.md"
  local out rc; out=$(bash "$RTS" detect "$W"); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then pass "감지 0개 → 빈 stdout + exit 0"
  else fail "0-어댑터 (rc=$rc out='$out')"; fi
  rmw
}

# T42 + M20: 폴리글랏 — 두 어댑터가 **함께** 반환된다 (단일-어댑터 픽스처로는 못 잡는다)
case_polyglot() {
  mkw; mkdir -p "$W/tests"
  : > "$W/tests/test_a.py"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  local got; got=$(runners "$W" | sort | tr '\n' ',')
  if [[ "$got" == "shell,unittest," ]]; then pass "폴리글랏 → 어댑터 2개 모두 반환"
  else fail "폴리글랏 (got: $got, expected shell,unittest,)"; fi
  rmw
}

# AC54: pytest/unittest 상호배타 · jest/vitest 판별불가 → npm-script 폴백
case_conflict_python() {
  mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "pytest," ]] && pass "pytest 설정 존재 → unittest 미주장" || fail "py 충돌 ($got)"
  rmw
}
case_conflict_js_ambiguous() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"run-tests"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "npm-script," ]] && pass "jest+vitest 판별불가 → npm-script 폴백" || fail "js 모호 ($got)"
  rmw
}
case_conflict_js_resolved() {
  mkw; printf '{"devDependencies":{"jest":"29","vitest":"1"},"scripts":{"test":"vitest run"}}' > "$W/package.json"
  local got; got=$(runners "$W" | tr '\n' ',')
  [[ "$got" == "vitest," ]] && pass "scripts.test가 vitest 호출 → vitest" || fail "js 해소 ($got)"
  rmw
}

# T34 후반 + AC38: SKILL.md에 어댑터 감지 조건 재구현이 없다
# (body-unique한 감지 조건 문자열들이 SKILL.md에 등장하면 표를 복제한 것)
case_no_reimpl_in_skill() {
  local bad=0 s
  for s in 'devDependencies' 'pytest.ini' 'Cargo.toml' 'go.mod'; do
    if grep -qF "$s" "$SKILL"; then echo "    SKILL.md가 감지 조건 '$s'를 담고 있음"; bad=1; fi
  done
  [[ $bad -eq 0 ]] && pass "SKILL.md에 어댑터 감지 표 재구현 0회" || fail "SKILL.md 감지 표 재구현"
}

# 컨트롤러 룰링 회귀 락: pytest 감지는 **레포 선언**만 본다. 앰비언트 인터프리터 프로브가
# 다시 들어오면 같은 레포가 머신마다 다르게 감지되고, 설정 없는 pytest 레포가 unittest 로
# 새어 bare 함수 테스트가 조용히 0개 실행된다.
case_no_ambient_pytest_probe() {
  if grep -q 'import pytest' "$RTS"; then
    fail "앰비언트 pytest 프로브 재도입됨 (레포 선언 기반이어야 함)"
  else
    pass "앰비언트 pytest 프로브 0회 — 감지는 레포 선언만 본다"
  fi
}

# T37 + M17 + AC41: setup_cmd가 양측에서 **동일 문자열**로 나온다.
# 결과값만 보면 두 측이 그럴듯하게 나오므로 호출 문자열 대조로만 잡힌다.
case_setup_cmd_identical_both_sides() {
  local a b t sa sb
  a=$(mktemp -d); b=$(mktemp -d)
  for t in "$a" "$b"; do
    mkdir -p "$t/tests"; : > "$t/tests/test_x.py"; : > "$t/requirements.txt"
  done
  sa=$(bash "$RTS" detect "$a" | awk '$1 == "setup_cmd:" { $1=""; sub(/^ /,""); print }')
  sb=$(bash "$RTS" detect "$b" | awk '$1 == "setup_cmd:" { $1=""; sub(/^ /,""); print }')
  if [[ -n "$sa" && "$sa" == "$sb" && "$sa" != "-" ]]; then
    pass "동일 형상 두 트리 → setup_cmd 동일 문자열 ('$sa')"
  else fail "setup_cmd 비대칭 (a='$sa' b='$sb')"; fi
  rm -rf "$a" "$b"
}

# T47 + M23 + AC50: 빌드 산출물 디렉토리는 트리별로 **다른** 경로여야 한다.
# 공유하면 기준선이 HEAD의 컴파일 결과를 재사용해 조용히 틀린 귀속을 만든다.
case_build_output_not_shared() {
  local a b ta tb
  a=$(mktemp -d); b=$(mktemp -d)
  ta=$(bash "$RTS" cargo-target-dir "$a" 2>/dev/null || true)
  tb=$(bash "$RTS" cargo-target-dir "$b" 2>/dev/null || true)
  if [[ -n "$ta" && -n "$tb" && "$ta" != "$tb" && "$ta" == "$a"* && "$tb" == "$b"* ]]; then
    pass "CARGO_TARGET_DIR가 트리별 독립 ('$ta' != '$tb')"
  else fail "CARGO_TARGET_DIR 공유 위험 (a='$ta' b='$tb')"; fi
  # node_modules / .venv를 트리 밖으로 내보내는 코드 경로가 없어야 한다
  if grep -qE 'NODE_PATH=|VIRTUAL_ENV=|--prefix[[:space:]]' "$RTS"; then
    fail "트리 밖 deps 경로 지정 코드 존재"
  else
    pass "node_modules/.venv 트리 밖 지정 0회"
  fi
  rm -rf "$a" "$b"
}

# T41 + §11 ⑨: 아티팩트 유출 **실측** — make 스텁 레포에서 run 후 비-ignored 신규 파일.
# V1(devbrew self-dogfood)은 Makefile/npm-script 테스트가 없어 이것을 구조적으로 측정
# 못 한다. 이 픽스처가 §11 ⑨의 make 쪽 측정 경로다.
#
# **주의 — 이 케이스의 `^\.qg-` 술어는 make 어댑터에서 구조적으로 발화할 수 없다.**
# make 어댑터에는 스크립트가 고르는 아티팩트 경로가 아예 없기 때문이다. 스크립트가
# **자기가 정한 경로로** 산출물을 유도하는 유일한 어댑터는 cargo 이고, 그 술어의 진짜
# 대상은 아래 case_cargo_artifacts_are_gitignored 다 (최종 whole-branch 리뷰 C1:
# 옳은 술어가 틀린 대상을 겨누고 있었다). 여기 남긴 것은 make 쪽 측정 자체가 §11 ⑨의
# 관측 경로이기 때문이며, 회귀 이빨은 cargo 케이스가 갖는다.
case_artifact_leak_measurement() {
  local t leaked; t=$(mktemp -d)
  ( cd "$t" && git init -q && git config user.email t@t.test && git config user.name tester )
  printf 'test:\n\t@touch build.log\n' > "$t/Makefile"
  ( cd "$t" && git add -A && git commit -qm init )
  bash "$RTS" run "$t" make bulk BULK >/dev/null 2>&1
  leaked=$( cd "$t" && git ls-files --others --exclude-standard )
  echo "    [측정] make 어댑터 실행 후 비-ignored 신규 파일: ${leaked:-<없음>}"
  # 실패 조건은 **스크립트 자신이** 유출을 만드는 경우뿐이다. 러너가 만든 유출은
  # 통제 밖이므로 §11 ⑨의 잔여 갭으로 기록될 뿐 여기서 RED가 아니다.
  if printf '%s\n' "$leaked" | grep -q '^\.qg-'; then
    fail "run 자신이 비-ignored 아티팩트를 남김"
  else
    pass "run 자신은 비-ignored 아티팩트를 남기지 않음"
  fi
  rm -rf "$t"
}

# 최종 whole-branch 리뷰 C1 — cargo 어댑터가 **모든 Rust 레포에서 terminal false FAIL**
# 을 보장하던 결함의 회귀 락.
#
# 왜 기존 세 케이스가 전부 이것을 놓쳤는가(같은 함정을 재생산하지 않기 위해 기록):
#   · case_build_output_not_shared           → 경로 **문자열**만 비교 (a != b)
#   · case_run_cargo_uses_cargo_target_dir_helper → cargo 스텁이 **디렉토리를 만들지 않음**
#   · case_artifact_leak_measurement          → 옳은 술어(`^\.qg-`)를 **make** 에 겨눔
# 셋 다 GREEN 인 채로 `.qg-cargo-target` 이 살아 있었다. 그래서 이 케이스는 (1) 실물
# cargo 처럼 CARGO_TARGET_DIR **안에 파일을 실제로 만드는** 스텁을 쓰고, (2) `cargo new`
# 가 쓰는 그대로의 `.gitignore`(`/target`)를 둔 **실제 git 레포**에서, (3) git 이 보는
# 비-ignored 신규 파일을 잰다 — R7 의 mutation-guard 가 재는 것과 같은 질문이다.
case_cargo_artifacts_are_gitignored() {
  local t bindir leaked
  t=$(mktemp -d)
  ( cd "$t" && git init -q && git config user.email t@t.test && git config user.name tester )
  printf '[package]\nname="x"\nversion="0.1.0"\n' > "$t/Cargo.toml"
  printf '/target\n' > "$t/.gitignore"     # `cargo new` 가 생성하는 그대로
  ( cd "$t" && git add -A && git commit -qm init )

  bindir=$(mktemp -d)
  {
    printf '#!/usr/bin/env bash\n'
    printf 'd="${CARGO_TARGET_DIR:-target}"\n'
    printf 'mkdir -p "$d/debug/deps" || exit 1\n'
    printf ': > "$d/debug/deps/libx.rlib"\n'
    printf ': > "$d/CACHEDIR.TAG"\n'
    printf 'exit 0\n'
  } > "$bindir/cargo"
  chmod +x "$bindir/cargo"

  PATH="$bindir:$PATH" bash "$RTS" run "$t" cargo bulk BULK >/dev/null 2>&1
  leaked=$( cd "$t" && git ls-files --others --exclude-standard )
  echo "    [측정] cargo 어댑터 실행 후 비-ignored 신규 파일: ${leaked:-<없음>}"
  if [[ -z "$leaked" ]]; then
    pass "cargo 산출물이 레포의 .gitignore(/target)에 덮임 — disallowed_new_files 0"
  else
    fail "cargo 산출물 유출 → mutation-guard forced_downgrade → terminal FAIL ($leaked)"
  fi
  # 같은 술어를 **발화 가능한 대상**에 겨눈다: qg 가 발명한 이름은 어떤 레포도 안 덮는다
  if printf '%s\n' "$leaked" | grep -q '^\.qg-'; then
    fail "qg-발명 아티팩트 경로가 트리에 남음"
  else
    pass "qg-발명 아티팩트 경로 0회"
  fi
  rm -rf "$t" "$bindir"
}

# 최종 whole-branch 리뷰 C2 — 도구 부재가 `PRE_EXISTING` 으로 채점되어 **테스트 0개로
# PASS** 가 나던 결함의 회귀 락. 감지는 레포 선언(go.mod)을 보고 그것이 옳다 — 이 락은
# 감지가 아니라 **실행 직전 가용성**을 잰다. PATH 를 최소 스텁 집합으로 갈아 도구 부재를
# 재현 가능하게 만든다(go 가 깔린 머신에서도 같은 결과여야 회귀 락으로 쓸 수 있다).
# 하류까지 이어서 재는 것이 핵심이다 — exit 3 만 확인하면 `PRE_EXISTING → PASS` 라는
# 원래 결함의 종착점을 여전히 못 본다.
case_missing_toolchain_blocks_pass() {
  local w bindir t p det out rc yaml
  w=$(mktemp -d); mkdir -p "$w/pkg"
  printf 'module x\n' > "$w/go.mod"; printf 'package pkg\n' > "$w/pkg/a_test.go"
  bindir=$(mktemp -d)
  for t in bash sh find grep head awk sed cat tr dirname basename python3 git; do
    p=$(command -v "$t" 2>/dev/null) && ln -s "$p" "$bindir/$t"
  done

  # 먼저 픽스처 자체를 증명한다: 축소 PATH 가 **감지**를 죽인 것이 아니다.
  det=$(PATH="$bindir" bash "$RTS" detect "$w" | awk '$1=="runner:"{print $2}' | tr '\n' ',')
  if [[ "$det" != "go," ]]; then
    fail "픽스처 무효: 축소 PATH 에서 감지가 'go,' 가 아님 ('$det')"; rm -rf "$w" "$bindir"; return
  fi
  pass "픽스처: 축소 PATH 에서도 go 는 여전히 감지된다 (감지는 레포 선언 기반)"

  out=$(PATH="$bindir" bash "$RTS" run "$w" go per-unit pkg 2>/dev/null); rc=$?
  if [[ $rc -eq 3 && "$out" == "pkg${TAB}unrun${TAB}-" ]]; then
    pass "toolchain 부재 → exit 3 + 전 unit unrun (설계 §5.10 row 3 · AC34 · AC44)"
  else
    fail "toolchain 부재가 exit 3 로 안 감 (rc=$rc out='$out')"
  fi

  # 하류: 이 행이 양측에 오면 PASS 가 **불가능**해야 한다.
  printf 'pkg\n' > "$w/expected.txt"; printf '%s\n' "$out" > "$w/side.tsv"
  yaml=$(python3 "$PLUGIN_ROOT/scripts/diff-test-results.py" \
           --expected "$w/expected.txt" --baseline "$w/side.tsv" --head "$w/side.tsv" \
           --granularity package --runner go 2>&1)
  if printf '%s\n' "$yaml" | grep -q 'baseline_unrunnable: true' \
     && printf '%s\n' "$yaml" | grep -q 'attribution_status: degraded'; then
    pass "toolchain 부재가 PASS 를 막는다 (baseline_unrunnable + attribution degraded)"
  else
    fail "toolchain 부재인데 PASS 가 가능한 귀속이 나옴:
$yaml"
  fi
  rm -rf "$w" "$bindir"
}

# 최종 whole-branch 리뷰 C2(이월분) — `pytest-cov` 만 선언한 레포가 unittest 로 새면
# 모듈-레벨 bare `def test_…` 가 **0개 수집 + exit 0** 으로 조용히 통과한다. 초록 exit
# 이라 어떤 degrade 신호도 안 뜨므로 exit 127 보다 나쁜 실패다.
case_pytest_plugin_only_declaration() {
  local w got
  w=$(mktemp -d); mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  printf 'pytest-cov==5.0.0\npytest-mock\n' > "$w/requirements.txt"
  got=$(runners "$w" | tr '\n' ',')
  [[ "$got" == "pytest," ]] \
    && pass "pytest-cov/-mock 만 선언 → pytest (unittest 로 새지 않음)" \
    || fail "플러그인-only 선언 ($got)"
  # 접두 오탐은 여전히 막혀야 한다 — 상위집합화가 경계를 무너뜨리지 않았는지 확인
  local w2 got2
  w2=$(mktemp -d); mkdir -p "$w2/tests"; : > "$w2/tests/test_a.py"
  printf 'mypytester\n' > "$w2/requirements.txt"
  got2=$(runners "$w2" | tr '\n' ',')
  [[ "$got2" == "unittest," ]] \
    && pass "'mypytester' 는 pytest 선언이 아니다 (접두 경계 유지)" \
    || fail "접두 오탐 ($got2)"
  rm -rf "$w" "$w2"
}

# 최종 whole-branch 리뷰 I3 — setup 이 만든 환경을 run 이 **실제로 쓰는가**.
# 결과값만 보면 두 경로가 똑같이 그럴듯하므로 **실행 argv 관측**으로만 잡힌다.
# (결함 당시: setup 은 `uv sync --frozen`, 실행은 앰비언트 `python3 -m pytest` —
#  가장 흔한 두 현대 Python 레이아웃에서 setup 이 실행에 대해 no-op 이었다.)
case_python_setup_and_run_share_env() {
  local w bindir observed scmd
  w=$(mktemp -d); mkdir -p "$w/tests"
  : > "$w/tests/test_a.py"; : > "$w/uv.lock"; : > "$w/conftest.py"
  scmd=$(setup_cmd_of_tree "$w")
  [[ "$scmd" == "uv sync --frozen" ]] \
    && pass "uv.lock → setup_cmd 'uv sync --frozen'" || fail "uv setup_cmd ('$scmd')"

  bindir=$(mktemp -d)
  record_stub "$bindir/uv" uv "$w/.observed"
  PATH="$bindir:$PATH" bash "$RTS" run "$w" pytest per-unit tests/test_a.py >/dev/null 2>&1
  observed=$(cat "$w/.observed" 2>/dev/null || echo "<관측 안 됨>")
  printf '%s\n' "$observed" | grep -q '^uv sync --frozen$' \
    && pass "setup 이 uv 로 실행됨" || fail "setup 미실행 (관측: $observed)"
  if printf '%s\n' "$observed" | grep -q '^uv run python -m pytest -p no:cacheprovider'; then
    pass "run 이 setup 이 만든 환경(uv run python)으로 테스트를 실행"
  else
    fail "run 이 앰비언트 인터프리터를 씀 — setup 이 실행에 대해 no-op (관측: $observed)"
  fi
  rm -rf "$w" "$bindir"
}

# 최종 whole-branch 리뷰 I3(두 번째 축) — requirements.txt 분기가 **샌드박스를 탈출**해
# 사용자의 system/user site-packages 를 바꾸던 결함. 음의 락(앰비언트 pip 부재)만으로는
# 분기를 통째로 지워도 통과하므로, **양의 짝**(트리-로컬 .venv 가 실제로 쓰이는가)을
# 실행 argv 로 함께 잰다.
case_requirements_env_is_sandbox_local() {
  local w bindir scmd observed
  w=$(mktemp -d); mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  printf 'pytest\n' > "$w/requirements.txt"
  scmd=$(setup_cmd_of_tree "$w")
  case "$scmd" in
    *".venv/bin/python -m pip install"*) pass "requirements.txt → 트리-로컬 .venv 로 설치 ('$scmd')" ;;
    *) fail "requirements setup_cmd 가 트리-로컬이 아님 ('$scmd')" ;;
  esac
  case "$scmd" in
    "python3 -m pip install"*) fail "앰비언트 pip 설치 분기 잔존 — 샌드박스 밖을 바꾼다" ;;
    *) pass "앰비언트 pip 설치 분기 없음" ;;
  esac

  # 실행 argv 관측: python3 스텁으로 venv 생성을 no-op 화하고, .venv/bin/python 스텁이
  # 실제로 호출되는지 본다. 앰비언트로 회귀하면 .venv 스텁은 한 번도 안 불린다.
  bindir=$(mktemp -d)
  { printf '#!/usr/bin/env bash\n'
    printf 'case "${1:-}" in -) exit 1 ;; esac\n'   # pkg_field 는 실패(=미감지)가 fail-closed
    printf 'printf "py3 %%s\\n" "$*" >> %s\n' "$(printf '%q' "$w/.observed")"
    printf 'exit 0\n'
  } > "$bindir/python3"; chmod +x "$bindir/python3"
  mkdir -p "$w/.venv/bin"; record_stub "$w/.venv/bin/python" venvpy "$w/.observed"
  PATH="$bindir:$PATH" bash "$RTS" run "$w" pytest per-unit tests/test_a.py >/dev/null 2>&1
  observed=$(cat "$w/.observed" 2>/dev/null || echo "<관측 안 됨>")
  if printf '%s\n' "$observed" | grep -q '^venvpy -m pytest -p no:cacheprovider'; then
    pass "run 이 트리-로컬 .venv 인터프리터로 테스트를 실행"
  else
    fail "run 이 .venv 를 쓰지 않음 (관측: $observed)"
  fi
  rm -rf "$w" "$bindir"
}

# 최종 whole-branch 리뷰 I6 — 락파일 없는 레포에 `npm install` 을 돌리면 npm 이
# package-lock.json 을 새로 만든다. 그런 레포는 정의상 그것을 gitignore 하지 않으므로
# C1 과 **같은 terminal-FAIL 클래스**가 된다.
case_npm_install_writes_no_lockfile() {
  local w scmd t leaked
  w=$(mktemp -d); printf '{"scripts":{"test":"node t.js"}}' > "$w/package.json"
  scmd=$(setup_cmd_of_tree "$w")
  case "$scmd" in
    *--no-package-lock*) pass "락파일 없는 레포 → '$scmd'" ;;
    *) fail "npm install 이 락파일을 쓴다 ('$scmd')" ;;
  esac
  # 락파일이 **있는** 레포는 여전히 `npm ci` 다 (수정이 다른 분기를 갉아먹지 않았는지)
  : > "$w/package-lock.json"
  [[ "$(setup_cmd_of_tree "$w")" == "npm ci" ]] \
    && pass "락파일 있는 레포 → npm ci (무변경)" || fail "npm ci 분기 손상"

  if command -v npm >/dev/null 2>&1; then
    t=$(mktemp -d)
    ( cd "$t" && git init -q && git config user.email t@t.test && git config user.name tester )
    printf '{"name":"x","version":"1.0.0","scripts":{"test":"true"}}' > "$t/package.json"
    printf 'node_modules/\n' > "$t/.gitignore"
    ( cd "$t" && git add -A && git commit -qm init )
    bash "$RTS" run "$t" npm-script bulk BULK >/dev/null 2>&1
    leaked=$( cd "$t" && git ls-files --others --exclude-standard )
    echo "    [측정] npm-script 어댑터 실행 후 비-ignored 신규 파일: ${leaked:-<없음>}"
    [[ -z "$leaked" ]] && pass "npm 설치가 비-ignored 신규 파일을 남기지 않음 (실측)" \
                       || fail "npm 설치 유출 → mutation-guard terminal FAIL ($leaked)"
    rm -rf "$t"
  else
    echo "    [degrade] npm 미설치 — 실측 arm 생략, 문자열 arm 만 검증됨"
  fi
  rm -rf "$w"
}

# 리뷰 Finding 3: cargo-target-dir 서브커맨드와 run 의 cargo 실행 분기가 실제로 같은 값을
# 쓰는지 실행으로 검증한다 — 소스가 흩어진 두 리터럴로 재발하면(한쪽만 편집) 이 케이스가
# 잡는다. cargo 를 PATH 스텁으로 바꿔 실제 CARGO_TARGET_DIR 환경변수를 관측한다
# (실물 cargo/rustc 설치에 의존하지 않는다).
case_run_cargo_uses_cargo_target_dir_helper() {
  local w bindir expected observed
  w=$(mktemp -d); printf '[package]\nname="x"\n' > "$w/Cargo.toml"
  bindir=$(mktemp -d)
  {
    printf '#!/usr/bin/env bash\n'
    printf 'echo "$CARGO_TARGET_DIR" > "%s/.observed-target"\n' "$w"
    printf 'exit 0\n'
  } > "$bindir/cargo"
  chmod +x "$bindir/cargo"
  expected=$(bash "$RTS" cargo-target-dir "$w")
  PATH="$bindir:$PATH" bash "$RTS" run "$w" cargo bulk BULK >/dev/null 2>&1
  observed=$(cat "$w/.observed-target" 2>/dev/null || echo "<관측 안 됨>")
  if [[ "$observed" == "$expected" ]]; then
    pass "run 의 cargo 실행이 cargo-target-dir 서브커맨드와 같은 값을 씀 ('$expected')"
  else
    fail "cargo target dir 불일치 (expected='$expected' observed='$observed')"
  fi
  rm -rf "$w" "$bindir"
}

for c in case_pytest case_unittest case_pytest_declared_without_config case_shell case_jest case_vitest case_go case_cargo \
         case_make case_npmscript case_zero_adapters case_polyglot \
         case_conflict_python case_conflict_js_ambiguous case_conflict_js_resolved \
         case_no_reimpl_in_skill case_no_ambient_pytest_probe \
         case_setup_cmd_identical_both_sides case_build_output_not_shared case_artifact_leak_measurement \
         case_run_cargo_uses_cargo_target_dir_helper \
         case_cargo_artifacts_are_gitignored case_missing_toolchain_blocks_pass \
         case_pytest_plugin_only_declaration case_python_setup_and_run_share_env \
         case_requirements_env_is_sandbox_local case_npm_install_writes_no_lockfile; do
  echo "== $c"; $c
done
echo "── runner adapters: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
