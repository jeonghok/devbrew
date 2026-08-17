#!/usr/bin/env bash
# run-own-tests.sh 의 세 결함 회귀 락.
#
#  A) 여러 테스트 디렉토리를 **전부** 돈다 (break 제거).
#  B) 앞 디렉토리의 실패가 뒤 디렉토리의 성공에 **덮이지 않는다** (why는 append,
#     ran은 OR). break만 지우면 여기가 새 fail-open이 된다.
#  C) passed/total 이 실제 값으로 채워진다 (지금은 항상 null).
#  D) 셸 테스트도 수집·실행한다.
set -u
# PR1 시점 경로는 plugins/plugin-audit/scripts/tests/ (Task 12가 plugins/plugin-audit/tests/로
# 옮긴 뒤엔 3-up이 맞다) — 지금은 tests/ 로부터 repo root까지 4단 상위: tests -> scripts ->
# plugin-audit -> plugins -> devbrew. 〔실측 2026-08-17: 3-up은 .../devbrew/plugins에서 멈춘다〕
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SUT="$ROOT/plugins/plugin-audit/scripts/run-own-tests.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }
TMP="$(mktemp -d -t pa-own-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# qg-worktree.sh 를 스텁으로 대체한다 — 실제 샌드박스를 만들면 이 테스트가
# git 상태에 의존하고 느려진다. 스텁은 계약(3줄 stdout / mutation-guard)만 흉내낸다.
mk_stub_qg() {
  cat > "$TMP/qg-stub.sh" <<STUB
#!/usr/bin/env bash
case "\$1" in
  create-sandbox) printf '%s\n%s\n%s\n' "$TMP/sandbox" base digest ;;
  mutation-guard) echo "forced_downgrade: no" ;;
  remove) : ;;
esac
exit 0
STUB
  chmod +x "$TMP/qg-stub.sh"
}

mk_target() {   # $1 = 시나리오
  rm -rf "$TMP/sandbox"; mkdir -p "$TMP/sandbox/plugins/tgt"
  case "$1" in
    two-dirs-first-fails)
      mkdir -p "$TMP/sandbox/plugins/tgt/tests" "$TMP/sandbox/plugins/tgt/hooks/tests"
      cat > "$TMP/sandbox/plugins/tgt/tests/test_a.py" <<'PY'
import unittest
class T(unittest.TestCase):
    def test_fails(self): self.assertTrue(False)
PY
      cat > "$TMP/sandbox/plugins/tgt/hooks/tests/test_b.py" <<'PY'
import unittest
class T(unittest.TestCase):
    def test_ok(self): self.assertTrue(True)
PY
      ;;
    counts)
      mkdir -p "$TMP/sandbox/plugins/tgt/tests"
      cat > "$TMP/sandbox/plugins/tgt/tests/test_c.py" <<'PY'
import unittest
class T(unittest.TestCase):
    def test_1(self): pass
    def test_2(self): pass
    def test_3(self): pass
PY
      ;;
    shell)
      mkdir -p "$TMP/sandbox/plugins/tgt/tests"
      printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/sandbox/plugins/tgt/tests/test_sh_ok.sh"
      printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/sandbox/plugins/tgt/tests/test_sh_bad.sh"
      chmod +x "$TMP/sandbox/plugins/tgt/tests/"*.sh
      ;;
  esac
}

run_sut() { bash "$SUT" plugins/tgt testsid --qg-worktree "$TMP/qg-stub.sh" 2>/dev/null; }

mk_stub_qg

# A + B — 두 디렉토리, 앞이 실패
mk_target two-dirs-first-fails
out="$(run_sut)"
echo "      $out"
case "$out" in
  *'"total": 2'*|*'"total":2'*) ok "A: 두 디렉토리를 모두 돌아 total=2" ;;
  *) no "A: 두 디렉토리 합산이 안 됐다 (out=$out)" ;;
esac
case "$out" in
  *'"why": null'*|*'"why":null'*) no "B: 앞 디렉토리의 실패가 사라졌다 — 뒤 성공이 덮었다 (fail-open)" ;;
  *) ok "B: 실패 사유가 보존됐다" ;;
esac

# C — 카운트
mk_target counts
out="$(run_sut)"
echo "      $out"
case "$out" in
  *'"passed": 3'*|*'"passed":3'*) ok "C: passed=3 (null 아님)" ;;
  *) no "C: passed 가 실제 값이 아니다 (out=$out)" ;;
esac
case "$out" in
  *'"total": 3'*|*'"total":3'*) ok "C: total=3" ;;
  *) no "C: total 이 실제 값이 아니다 (out=$out)" ;;
esac

# D — 셸 수집
mk_target shell
out="$(run_sut)"
echo "      $out"
case "$out" in
  *'"total": 2'*|*'"total":2'*) ok "D: 셸 테스트 2건 수집" ;;
  *) no "D: 셸 테스트를 수집하지 않았다 (out=$out)" ;;
esac
case "$out" in
  *'"passed": 1'*|*'"passed":1'*) ok "D: 셸 통과 1건 (실패 1건을 통과로 세지 않음)" ;;
  *) no "D: 셸 통과 수가 틀렸다 (out=$out)" ;;
esac

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
