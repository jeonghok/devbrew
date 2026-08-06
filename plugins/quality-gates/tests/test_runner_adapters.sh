#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh detect의 러너 어댑터 9종 (design §5.9).
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

# /qg iter-5 C6 — **문서의 어댑터 개수 주장이 닫힌 집합에서 파생된다.**
#
# 배경: 6곳이 "어댑터 8종"이라 적고 있었는데 실제 닫힌 집합은 **9종**이었다
# (`npm-script` 가 늘어난 뒤 아무도 세지 않았다). CHANGELOG 는 같은 줄에서 **이름을
# 9개 나열하면서 8종이라고** 적었다 — 사람도 리뷰어도 그 줄을 여러 번 읽고 지나갔다.
# 숫자를 손으로 고치기만 하면 다음 어댑터에서 똑같이 어긋난다. 그래서 개수를
# **`granularity_of` 의 닫힌 집합에서 파생**하고 문서 주장과 대조한다.
#
# 코퍼스는 **플러그인 디렉토리로 한정한다.** `docs/superpowers/specs/…-design.md` 는
# 이 플러그인의 파일이 아니라 리포 문서이고, 플러그인 테스트가 리포 문서를 읽기
# 시작하면 레이어가 깨져 문서 편집마다 stale-red 가 난다.
case_adapter_count_derives_from_closed_set() {
  # 닫힌 집합 = granularity_of 의 case arm 들 (`*` 제외). 어댑터 표의 유일 소유자.
  local names n
  names=$(sed -n '/^granularity_of() {/,/^}/p' "$RTS" \
          | grep -oE '^[[:space:]]+[a-z|*-]+\)' | tr -d ' )' | tr '|' '\n' | grep -vx '\*')
  n=$(printf '%s\n' "$names" | grep -c .)
  if [[ "$n" -lt 2 ]]; then
    fail "닫힌 집합 파싱 실패 (n=$n) — 아래 대조가 공허해진다"; return
  fi

  # 파서가 엉뚱한 토큰을 셌는지 교차 확인한다 (계측기 검증). `run` 은 **실재하는 빈
  # 트리**에서 미지 러너면 exit 2(사용 오류), 알려졌지만 미감지면 exit 3 을 낸다 —
  # 존재하지 않는 경로를 주면 러너와 무관하게 항상 exit 2 라 아무것도 구별하지 못한다.
  local nm probe_dir; probe_dir=$(mktemp -d) || exit 1
  for nm in $names; do
    bash "$RTS" run "$probe_dir" "$nm" per-unit X >/dev/null 2>&1
    if [[ $? -eq 2 ]]; then
      rm -rf "$probe_dir"; fail "닫힌 집합 파싱 오염: '$nm' 은 러너 이름이 아니다"; return
    fi
  done
  rm -rf "$probe_dir"

  # 플러그인 안의 모든 `러너 어댑터 N종` 주장이 n 과 같아야 한다 (∀).
  local bad=0 found=0 hit
  while IFS= read -r hit; do
    found=$((found + 1))
    local claimed; claimed=$(sed -E 's/.*러너 어댑터 ([0-9]+)종.*/\1/' <<<"$hit")
    [[ "$claimed" == "$n" ]] || { bad=1; echo "    (불일치 ${claimed}≠${n}) ${hit:0:110}"; }
  done < <(grep -rn "러너 어댑터 [0-9]*종" "$PLUGIN_ROOT" 2>/dev/null)

  # 양의 짝 — 주장이 하나도 없으면 ∀ 는 공허하게 참이다. 코퍼스를 봤다는 증거.
  if [[ $found -eq 0 ]]; then
    fail "플러그인 안에 어댑터 개수 주장이 0건 — ∀ 가 공허하게 통과할 뻔했다"
  elif [[ $bad -eq 0 ]]; then
    pass "어댑터 개수 주장 ${found}곳이 닫힌 집합(${n}종)과 일치 (∀ + 코퍼스 실재)"
  else
    fail "어댑터 개수 주장이 닫힌 집합(${n}종)과 불일치"
  fi
}

# T34/T25: 러너 어댑터 9종 각각 감지
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
           --granularity package --mode bulk --runner go --baseline-detected go 2>&1)
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

# 라운드 2 NEW-1 — 환경 디렉토리 ignore 질의는 **후행 슬래시**여야 한다.
#
# `.gitignore` 의 디렉토리 전용 패턴(`.venv/`·`**/.venv/`·`/.venv/`)은 **아직 존재하지
# 않는** 경로에 대해 `check-ignore .venv` 로 매치되지 않는다(git 2.50.1 실측). 그리고
# 프로덕션은 언제나 부재 상태로 질의한다 — 기준선 워크트리는 갓 만들어지고,
# create-sandbox 는 git-ignored 파일을 일부러 제외한다. 그래서 **완전히 정상인 레포**의
# setup 이 조용히 꺼졌고, 준비 안 된 실행이 양측에서 똑같이 실패해
# `error → PRE_EXISTING → closed` = 테스트 0개 PASS 로 접혔다 — C2 가 죽이려던 verdict
# 행을 I3 의 게이트가 다른 문으로 되살린 것이다.
#
# **픽스처는 반드시 실제 git 레포여야 한다.** `mktemp -d` 는 비-git 이라 dir_is_ignored
# 가 무조건 안전을 반환해 게이트를 **아예 태우지 않는다** — 앞 라운드의 I3 테스트 두 개가
# 정확히 그 이유로 이 결함을 구조적으로 못 잡았다.
mk_git_repo() {   # mk_git_repo <ignore-line> → repo 경로
  local t; t=$(mktemp -d)
  ( cd "$t" && git init -q && git config user.email t@t.test && git config user.name tester )
  printf '%s\n' "$1" > "$t/.gitignore"
  printf '%s' "$t"
}
case_env_dir_gate_uses_directory_pattern() {
  local t b out rc yaml

  # ① 디렉토리 전용 패턴 = 정상 레포. setup 이 돌고 테스트가 실행돼야 한다.
  t=$(mk_git_repo '.venv/'); b=$(mktemp -d)
  : > "$t/uv.lock"; : > "$t/conftest.py"; mkdir -p "$t/tests"; : > "$t/tests/test_a.py"
  ( cd "$t" && git add -A && git commit -qm init )
  record_stub "$b/uv" uv "$t/.observed"
  out=$(PATH="$b:$PATH" bash "$RTS" run "$t" pytest per-unit tests/test_a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 0 && "$out" == "tests/test_a.py${TAB}pass${TAB}0" ]]; then
    pass "'.venv/' 디렉토리 패턴 레포에서 실행이 정상 진행 (부재 상태 질의)"
  else
    fail "정상 레포의 setup 이 꺼짐 → 테스트 0개 PASS 경로 (rc=$rc out='$out')"
  fi
  grep -q '^uv sync --frozen$' "$t/.observed" 2>/dev/null \
    && pass "그 레포에서 setup 이 실제로 실행됨" \
    || fail "setup 미실행 (관측: $(cat "$t/.observed" 2>/dev/null))"
  rm -rf "$t" "$b"

  # ② 진짜로 무시하지 않는 레포 → **조용한 setup skip 이 아니라** exit 3 degrade.
  #    조용히 건너뛰면 그 실행이 PRE_EXISTING 으로 접혀 PASS 가 된다(원 결함의 형태).
  t=$(mk_git_repo 'unrelated'); b=$(mktemp -d)
  : > "$t/uv.lock"; : > "$t/conftest.py"; mkdir -p "$t/tests"; : > "$t/tests/test_a.py"
  ( cd "$t" && git add -A && git commit -qm init )
  record_stub "$b/uv" uv "$t/.observed"
  out=$(PATH="$b:$PATH" bash "$RTS" run "$t" pytest per-unit tests/test_a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 3 && "$out" == "tests/test_a.py${TAB}unrun${TAB}-" ]]; then
    pass ".venv 미무시 레포 → exit 3 + unrun (조용한 skip 아님)"
  else
    fail "미무시 레포 처리 (rc=$rc out='$out')"
  fi
  # 측정하는 것을 그대로 적는다: 거부는 setup **이전**에 일어나므로 uv 는 setup·프로브·
  # 실행 어느 것으로도 호출되지 않는다. 한 번이라도 불렸다면 `.venv` 가 생겼다는 뜻이고
  # 그것이 terminal FAIL 의 씨앗이다.
  [[ ! -s "$t/.observed" ]] && pass "그 경우 uv 를 한 번도 호출하지 않음 (트리 오염 0)" \
                            || fail "거부했어야 할 트리에서 uv 가 호출됨 ($(cat "$t/.observed"))"
  printf 'tests/test_a.py\n' > "$t/expected.txt"; printf '%s\n' "$out" > "$t/side.tsv"
  yaml=$(python3 "$PLUGIN_ROOT/scripts/diff-test-results.py" --expected "$t/expected.txt" \
           --baseline "$t/side.tsv" --head "$t/side.tsv" --granularity file --mode per-unit --runner pytest \
           --baseline-detected pytest 2>&1)
  printf '%s\n' "$yaml" | grep -q 'baseline_unrunnable: true' \
    && pass "그 degrade 가 PASS 를 막는다 (baseline_unrunnable)" || fail "PASS 가 가능:
$yaml"
  rm -rf "$t" "$b"

  # ③ node_modules 쌍둥이 — 같은 헬퍼가 JS 쪽도 덮는가 (보고서 §9① 이월분)
  t=$(mk_git_repo 'node_modules/'); b=$(mktemp -d)
  printf '{"scripts":{"test":"true"}}' > "$t/package.json"
  ( cd "$t" && git add -A && git commit -qm init )
  record_stub "$b/npm" npm "$t/.observed"
  out=$(PATH="$b:$PATH" bash "$RTS" run "$t" npm-script bulk BULK 2>/dev/null); rc=$?
  [[ $rc -eq 0 && "$out" == "BULK${TAB}pass${TAB}0" ]] \
    && pass "'node_modules/' 패턴 레포에서 실행이 정상 진행" \
    || fail "node_modules 정상 레포가 막힘 (rc=$rc out='$out')"
  rm -rf "$t" "$b"

  t=$(mk_git_repo 'unrelated'); b=$(mktemp -d)
  printf '{"scripts":{"test":"true"}}' > "$t/package.json"
  ( cd "$t" && git add -A && git commit -qm init )
  record_stub "$b/npm" npm "$t/.observed"
  out=$(PATH="$b:$PATH" bash "$RTS" run "$t" npm-script bulk BULK 2>/dev/null); rc=$?
  [[ $rc -eq 3 && "$out" == "BULK${TAB}unrun${TAB}-" ]] \
    && pass "node_modules 미무시 레포 → exit 3 + unrun (terminal FAIL 도, 조용한 PASS 도 아님)" \
    || fail "node_modules 미무시 처리 (rc=$rc out='$out')"
  rm -rf "$t" "$b"
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

# ── /qg iter-1: go 어댑터가 "테스트 0개인데 초록" 으로 접히던 두 축 ────────────────
# 축 ①(codex conf 10, 실행 검증자가 실물 go1.23.4 로 재현): 모듈 모드에서 `.`/`/` 로
# 시작하지 않는 패턴은 **import 경로**다. `go test pkg/a` → "package pkg/a is not in std"
# → exit 1 → `fail`(error 도 아니라 가용성 프로브의 `unrun` 축에 닿지 못한다) → 양측
# 동일 → PRE_EXISTING → 테스트 0개로 PASS. 접두는 `run` 에서만 붙인다 — unit 문자열은
# 캐시 키이자 `--expected` 의 원소라 repo-상대 평문이어야 한다.
case_go_run_prefixes_package_with_dotslash() {
  local w b observed
  w=$(mktemp -d) || exit 1; b=$(mktemp -d) || exit 1
  printf 'module example.com/m\n' > "$w/go.mod"
  mkdir -p "$w/pkg/a"; : > "$w/pkg/a/a_test.go"
  record_stub "$b/go" go "$w/.observed"
  PATH="$b:$PATH" bash "$RTS" run "$w" go per-unit pkg/a >/dev/null 2>&1
  observed=$(cat "$w/.observed" 2>/dev/null || echo "<관측 안 됨>")
  printf '%s\n' "$observed" | grep -qx 'go test ./pkg/a' \
    && pass "go run: package unit 에 ./ 접두 (import 경로 오해석 차단)" \
    || fail "go run 이 import 경로로 넘김 (관측: $observed)"
  rm -rf "$w" "$b"
}

# 루트 패키지 `.` 은 **이미** 디렉토리 패턴이다. `./.` 로 이중 접두하면 안 된다 —
# 접두 로직을 "무조건 붙이기" 로 단순화하는 회귀를 이 케이스가 잡는다.
case_go_run_root_package_unchanged() {
  local w b observed
  w=$(mktemp -d) || exit 1; b=$(mktemp -d) || exit 1
  printf 'module example.com/m\n' > "$w/go.mod"; : > "$w/m_test.go"
  record_stub "$b/go" go "$w/.observed"
  PATH="$b:$PATH" bash "$RTS" run "$w" go per-unit . >/dev/null 2>&1
  observed=$(cat "$w/.observed" 2>/dev/null || echo "<관측 안 됨>")
  printf '%s\n' "$observed" | grep -qx 'go test \.' \
    && pass "go run: 루트 unit '.' 은 그대로 (이중 접두 없음)" \
    || fail "루트 unit 이 변형됨 (관측: $observed)"
  rm -rf "$w" "$b"
}

# 축 ②(adversarial 이 형제 위치로 지목): `exists_unit` 의 package 분기가 `-d` 만 보면
# `*_test.go` 없는 디렉토리가 "존재" 로 판정되고 `go test ./pkg` 가 "no test files" 로
# **exit 0** 을 내 `pass` 행이 선다 — 판정한 것이 없는데 초록이다. 실제 도달 경로:
# assign 은 `*_test.go` 만 claim 하지만, 그 unit 이 **기준선 트리**에서 돌 때 해당 테스트가
# 이번 diff 가 추가한 것이면 merge_base 에는 없다.
#
# 한 번의 호출에 양성(pkg/a, 테스트 있음)과 음성(pkg/b, 테스트 없음)을 함께 넣는다 —
# 양의 짝이 없으면 "전부 absent" 로 만드는 mutation 이 GREEN 이 된다.
case_go_package_without_tests_is_absent() {
  local w b out
  w=$(mktemp -d) || exit 1; b=$(mktemp -d) || exit 1
  printf 'module example.com/m\n' > "$w/go.mod"
  mkdir -p "$w/pkg/a" "$w/pkg/b"
  : > "$w/pkg/a/a_test.go"          # 테스트 있음 → 실행 대상
  : > "$w/pkg/b/b.go"               # 소스만 있고 테스트 없음 → absent 여야 한다
  record_stub "$b/go" go "$w/.observed"
  out=$(PATH="$b:$PATH" bash "$RTS" run "$w" go per-unit pkg/a pkg/b 2>/dev/null | tr '\n' ';')
  if [[ "$out" == "pkg/a${TAB}pass${TAB}0;pkg/b${TAB}absent${TAB}-;" ]]; then
    pass "go: 테스트 없는 패키지는 absent · 있는 패키지는 실행(양의 짝)"
  else
    fail "go 패키지 존재 판정 (got: $out)"
  fi
  rm -rf "$w" "$b"
}

# ── /qg iter-2: 종료코드 표 확장을 되돌린 뒤의 락 ────────────────────────────
# iter-1 은 "미판정 실행이 pass/fail 로 보고" 를 CRITICAL 로 올렸고 표를 넓혔다.
# iter-2 가 그 수정이 **더 나쁜 결함**을 만들었음을 실행으로 재현했다 — pytest exit 2 는
# 수집/import 에러(제품 파손)인데 unrun 으로 보내면 `(pass, 2)` 비대칭이
# NEW_REGRESSION(defect=true, FAIL) 에서 SILENT_DROP(defect=false, SKIP) 으로 내려간다.
#
# 그래서 표는 127 하나로 되돌렸고, **여기서 잠그는 것은 매핑이 아니라 그 비대칭 속성**이다.
# 매핑만 잠그면 다음 사람이 "미판정 코드를 더 넣자" 는 같은 유혹에 같은 방식으로 빠진다.
exit_stub() {   # exit_stub <path> <code> — --version 프로브는 통과시키고 실행만 <code>
  { printf '#!/usr/bin/env bash\n'
    printf 'case "$*" in *--version*) exit 0 ;; esac\n'
    printf 'exit %s\n' "$2"
  } > "$1"
  chmod +x "$1"
}

case_exit_code_mapping() {
  local w b out code want ok=1
  w=$(mktemp -d) || exit 1; b=$(mktemp -d) || exit 1
  : > "$w/pytest.ini"; mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  # 127 만 unrun. 나머지는 0=pass · 1=fail · 그 외 error (이 변경 이전 동작).
  for pair in 0:pass 1:fail 2:error 4:error 5:error 124:error 126:error 137:error 127:unrun 101:error; do
    code="${pair%%:*}"; want="${pair#*:}"
    exit_stub "$b/python3" "$code"
    out=$(PATH="$b:$PATH" bash "$RTS" run "$w" pytest per-unit tests/test_a.py 2>/dev/null)
    if [[ "$out" != "tests/test_a.py${TAB}${want}${TAB}${code}" ]]; then
      fail "pytest exit ${code} → ${want} (got: '$out')"; ok=0
    fi
  done
  [[ "$ok" == "1" ]] && pass "종료코드→상태 매핑 10종 (127 만 unrun · 0/1 양의 짝 · 나머지 error)"
  rm -rf "$w" "$b"
}

# ★ 이 케이스가 진짜 락이다 — 매핑이 아니라 **비대칭 귀속**을 잰다.
# 기준선 green · HEAD 가 제품 파손으로 죽음 → 반드시 확증 제품결함이어야 한다.
# 어떤 미판정-코드 확장이든 이 속성을 깨면 여기서 빨개진다.
case_asymmetric_product_breakage_is_a_defect() {
  local w b d out code ok=1
  w=$(mktemp -d) || exit 1; b=$(mktemp -d) || exit 1; d=$(mktemp -d) || exit 1
  : > "$w/pytest.ini"; mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  printf 'tests/test_a.py\n' > "$d/expected.txt"
  printf 'tests/test_a.py\tpass\t0\n'  > "$d/base.tsv"
  for code in 2 4 5 124 126 137; do
    exit_stub "$b/python3" "$code"
    out=$(PATH="$b:$PATH" bash "$RTS" run "$w" pytest per-unit tests/test_a.py 2>/dev/null)
    printf '%s\n' "$out" > "$d/head.tsv"
    out=$(python3 "$PLUGIN_ROOT/scripts/diff-test-results.py" \
            --expected "$d/expected.txt" --baseline "$d/base.tsv" --head "$d/head.tsv" \
            --granularity file --mode per-unit --runner pytest --baseline-detected pytest 2>/dev/null \
          | awk '$1=="confirmed_product_defect:"{print $2}')
    if [[ "$out" != "true" ]]; then
      fail "기준선 pass · HEAD exit ${code} → confirmed_product_defect=${out} (true 여야 함)"; ok=0
    fi
  done
  [[ "$ok" == "1" ]] && pass "비대칭 제품 파손 6종이 전부 확증 제품결함 (회귀 재발 방지)"
  rm -rf "$w" "$b" "$d"
}

for c in case_pytest case_unittest case_pytest_declared_without_config case_shell case_jest case_vitest case_go case_cargo \
         case_go_run_prefixes_package_with_dotslash case_go_run_root_package_unchanged \
         case_go_package_without_tests_is_absent case_exit_code_mapping case_asymmetric_product_breakage_is_a_defect \
         case_make case_npmscript case_zero_adapters case_polyglot \
         case_conflict_python case_conflict_js_ambiguous case_conflict_js_resolved \
         case_no_reimpl_in_skill case_no_ambient_pytest_probe \
         case_setup_cmd_identical_both_sides case_build_output_not_shared case_artifact_leak_measurement \
         case_run_cargo_uses_cargo_target_dir_helper \
         case_cargo_artifacts_are_gitignored case_missing_toolchain_blocks_pass \
         case_pytest_plugin_only_declaration case_python_setup_and_run_share_env \
         case_requirements_env_is_sandbox_local case_npm_install_writes_no_lockfile \
         case_env_dir_gate_uses_directory_pattern \
         case_adapter_count_derives_from_closed_set; do
  echo "== $c"; $c
done
echo "── runner adapters: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
