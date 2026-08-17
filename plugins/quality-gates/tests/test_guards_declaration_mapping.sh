#!/usr/bin/env bash
# `# guards:` 선언 축 — 변경 파일의 **확장자와 무관하게** 선언 글롭에 걸리면
# 그 테스트가 후보에 든다.
#
# 왜 확장자별 arm이 아닌가: `.sh`·`.md` arm만 더하면 `.py` 사본(codex_findings_to_yaml.py
# 등)이 편집돼도 그것을 지키는 copy-of 락이 후보에 들지 않는다. 그러면 §12의
# "거의 모든 코드 변경에서 선택된다"가 거짓이 되는데, 확장자 3종 중 2종만 재는
# 측정은 그 거짓을 통과시킨다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SUT="$ROOT/plugins/quality-gates/scripts/compute-test-scope-candidates.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }
TMP="$(mktemp -d -t qg-guards-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 실제 리포가 아니라 격리된 git 트리에서 잰다 — 이 테스트가 리포 상태에 의존하면
# 다른 브랜치에서 결과가 달라진다.
mk_repo() {
  R="$TMP/repo"; rm -rf "$R"; mkdir -p "$R"
  ( cd "$R" && git init -q && git config user.email t@t && git config user.name t )
  mkdir -p "$R/plugins/qg/scripts" "$R/plugins/qg/agents" "$R/shared/tests" "$R/plugins/qg/skills/s"
  cp "$SUT" "$R/sut.sh"
  cp "$ROOT/plugins/quality-gates/scripts/resolve-baseline.sh" "$R/" 2>/dev/null || true
  printf 'x\n' > "$R/plugins/qg/scripts/mod.py"
  printf 'x\n' > "$R/plugins/qg/scripts/mod.sh"
  printf 'x\n' > "$R/plugins/qg/agents/a.md"
  printf 'x\n' > "$R/plugins/qg/skills/s/SKILL.md"
  cat > "$R/shared/tests/test_lock.sh" <<'LOCK'
#!/usr/bin/env bash
# guards: plugins/** shared/**
exit 0
LOCK
  chmod +x "$R/shared/tests/test_lock.sh"
  ( cd "$R" && git add -A && git commit -qm init )
}

candidates() {   # $1 = 건드릴 파일 (repo-상대)
  ( cd "$TMP/repo" && printf 'changed\n' >> "$1" && bash sut.sh 2>/dev/null )
}

for target in plugins/qg/scripts/mod.py plugins/qg/scripts/mod.sh \
              plugins/qg/agents/a.md plugins/qg/skills/s/SKILL.md; do
  mk_repo
  out="$(candidates "$target")"
  case "$out" in
    *shared/tests/test_lock.sh*) ok "guards: $target 변경 → 락이 후보에 든다" ;;
    *) no "guards: $target 변경 → 락이 후보에 없다 (출력: $(printf '%s' "$out" | tr '\n' ' '))" ;;
  esac
done

# 음의 짝 — 선언 글롭 **밖**의 변경에는 들지 않아야 한다. 없으면 "무엇이든 다 고른다"와
# 구별되지 않는다.
mk_repo
mkdir -p "$TMP/repo/docs"; printf 'x\n' > "$TMP/repo/docs/note.md"
( cd "$TMP/repo" && git add -A && git commit -qm docs )
out="$(candidates docs/note.md)"
case "$out" in
  *shared/tests/test_lock.sh*) no "guards: 글롭 밖 변경인데 락이 후보에 든다 — 무차별 선택" ;;
  *) ok "guards: 글롭 밖(docs/) 변경에는 락이 안 든다" ;;
esac

# 선언이 **없는** 테스트는 현행 동작 유지 — 자기 편집 시에만 후보.
mk_repo
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/repo/plugins/qg/tests/test_plain.sh" 2>/dev/null \
  || { mkdir -p "$TMP/repo/plugins/qg/tests"; printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/repo/plugins/qg/tests/test_plain.sh"; }
chmod +x "$TMP/repo/plugins/qg/tests/test_plain.sh"
( cd "$TMP/repo" && git add -A && git commit -qm plain )
out="$(candidates plugins/qg/scripts/mod.py)"
case "$out" in
  *test_plain.sh*) no "선언 없는 테스트가 남의 변경에 딸려 들어온다 — 회귀" ;;
  *) ok "선언 없는 테스트는 현행 동작 유지 (자기 편집 시에만)" ;;
esac

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
