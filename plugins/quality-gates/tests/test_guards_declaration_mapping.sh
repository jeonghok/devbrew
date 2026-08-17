#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/compute-test-scope-candidates.sh
# `# guards:` 선언 축 — 변경 파일의 **확장자와 무관하게** 선언 글롭에 걸리면
# 그 테스트가 후보에 든다.
#
# 왜 확장자별 arm이 아닌가: `.sh`·`.md` arm만 더하면 `.py` 사본(codex_findings_to_yaml.py
# 등)이 편집돼도 그것을 지키는 copy-of 락이 후보에 들지 않는다. 그러면 §12의
# "거의 모든 코드 변경에서 선택된다"가 거짓이 되는데, 확장자 3종 중 2종만 재는
# 측정은 그 거짓을 통과시킨다.
set -u
# 위 `# guards:` 선언의 짝 — 이 파일은 아무 경로도 스캔하지 않으므로 빈 출력이 정답이다.
# 답하지 않으면 test_guards_coverage_bidirectional.sh 가 이 스위트를 통째로 실행한다.
[ "${1:-}" = "--emit-scanned" ] && exit 0
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SUT="$ROOT/plugins/quality-gates/scripts/compute-test-scope-candidates.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
TMP="$(mktemp -d -t qg-guards-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 실제 리포가 아니라 격리된 git 트리에서 잰다 — 이 테스트가 리포 상태에 의존하면
# 다른 브랜치에서 결과가 달라진다.
#
# F4: 락 픽스처를 heredoc 리터럴로 쓰지 않는다. `# guards: ...`로 시작하는 줄이
# *이 테스트 파일 자신의* 소스에 나타나면, 선언-탐지 윈도우(head -30)가 넓어질 때
# (Task 6 등) 이 테스트 파일 자체가 "plugins/** shared/**를 지키는 락"으로
# 오탐지될 수 있다 — 마진이 두 줄뿐이라 취약. printf로 "guards"를 인자로 넘겨
# 소스 줄 자체는 `# guards:`로 시작하지 않게 하면서, 픽스처 파일의 바이트는
# 동일하게 만든다.
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
  { printf '#!/usr/bin/env bash\n'
    printf '# %s: plugins/** shared/**\n' guards
    printf 'exit 0\n'
  } > "$R/shared/tests/test_lock.sh"
  chmod +x "$R/shared/tests/test_lock.sh"
  ( cd "$R" && git add -A && git commit -qm init )
}

# F1 회귀 픽스처 — 선언이 **탭**으로 구분된 경우. 리뷰어 지적: `IFS=' ' read -a`는
# 공백만 자르므로 탭 구분 선언이 통째로 한 필드가 되어 아무 글롭에도 안 걸린다
# (출력 없음, rc=0 — "이 변경은 영향 없다"와 구별 불가). 이 픽스처는 그 회귀를
# 잡기 위한 것이지 우아함을 위한 것이 아니다. 여기서도 소스 줄이 `# guards:`로
# 시작하지 않도록 printf 인자로 분리한다(F4와 동일 이유).
mk_repo_tab() {
  R="$TMP/repo"; rm -rf "$R"; mkdir -p "$R"
  ( cd "$R" && git init -q && git config user.email t@t && git config user.name t )
  mkdir -p "$R/plugins/qg/scripts" "$R/shared/tests"
  cp "$SUT" "$R/sut.sh"
  cp "$ROOT/plugins/quality-gates/scripts/resolve-baseline.sh" "$R/" 2>/dev/null || true
  printf 'x\n' > "$R/plugins/qg/scripts/mod.py"
  { printf '#!/usr/bin/env bash\n'
    printf '# %s:\tplugins/**\tshared/**\n' guards
    printf 'exit 0\n'
  } > "$R/shared/tests/test_lock.sh"
  chmod +x "$R/shared/tests/test_lock.sh"
  ( cd "$R" && git add -A && git commit -qm init )
}

candidates() {   # $1 = 건드릴 파일 (repo-상대)
  ( cd "$TMP/repo" && printf 'changed\n' >> "$1" && bash sut.sh 2>/dev/null )
}

emit_guards() {   # $1 = 건드릴 파일 (repo-상대) — F3: --emit-guards 진단 출력
  ( cd "$TMP/repo" && printf 'changed\n' >> "$1" && bash sut.sh --emit-guards 2>/dev/null )
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

# F1 — 탭으로 구분된 선언도 공백 구분과 동일하게 락을 선택해야 한다.
mk_repo_tab
out="$(candidates plugins/qg/scripts/mod.py)"
case "$out" in
  *shared/tests/test_lock.sh*) ok "guards: 탭으로 구분된 선언도 락을 선택한다 (F1)" ;;
  *) no "guards: 탭으로 구분된 선언이 락을 선택 못 한다 — IFS 회귀 (출력: $(printf '%s' "$out" | tr '\n' ' '))" ;;
esac

# F3 — --emit-guards 는 Task 6 의 소비 지점이다. 아무 테스트도 이 플래그가 실제로
# 진단 출력을 내는지 확인하지 않으면, GUARDED 계산 전에 조기 종료해도 두 스위트
# 모두 무사히 통과한다.
mk_repo
out="$(emit_guards plugins/qg/scripts/mod.py)"
case "$out" in
  *shared/tests/test_lock.sh*) ok "guards: --emit-guards 가 후보 락 경로를 낸다 (F3)" ;;
  *) no "guards: --emit-guards 가 락 경로를 안 낸다 (출력: $(printf '%s' "$out" | tr '\n' ' '))" ;;
esac
finish
