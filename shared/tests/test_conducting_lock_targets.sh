#!/usr/bin/env bash
# guards: plugins/spec-distill/references/*.md shared/tests/test_skill_reference_pointers.sh shared/tests/test_ask_recommendation.sh plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_plain_gate_templates.sh
#
# 지휘 차례가 이름 붙이는 파일(차례 · 걸음 지시서 · 끝 절의 손 절차)마다 네 락의 대상 목록에 들어 있다 — 새 지시서가
# 질문 자리 · 쉬운 말 · 레포 전용 값 · 가리킴 락 어디서도 조용히 빠지지 않게 한다(AC7).
# Run (리포 루트에서): bash shared/tests/test_conducting_lock_targets.sh
set -u
ROOT="${LOCK_TARGETS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
export PYTHONDONTWRITEBYTECODE=1
TOC_PY="$ROOT/plugins/spec-distill/scripts/conductor_toc.py"
if [ ! -f "$TOC_PY" ]; then echo "conductor_toc.py 가 없다" >&2; exit 1; fi
F="$(python3 -I "$TOC_PY" files --plugin-root "$ROOT/plugins/spec-distill" --kind all | sed "s#^$ROOT/##")"
LOCKS="plugins/spec-distill/tests/test_plain_gate_templates.sh:emit shared/tests/test_ask_recommendation.sh:emit plugins/spec-distill/tests/test_repo_literals.sh:emit shared/tests/test_skill_reference_pointers.sh:guards"
if [ "${1:-}" = "--emit-scanned" ]; then  # test_guards_coverage_bidirectional.sh 가 읽는다 — 이 락이 읽는 경로
  printf '%s\n' "$F"
  for entry in $LOCKS; do printf '%s\n' "${entry%%:*}"; done
  exit 0
fi
. "$(cd "$(dirname "$0")" && pwd)/assert.sh"
if [ -z "$F" ]; then no "차례가 이름 붙인 파일이 하나도 없다 — 아래 단언이 공허하다"; finish; exit $?; fi
ok "차례가 이름 붙인 파일 $(printf '%s\n' "$F" | grep -c .)개를 읽었다"

# 락마다 대상 목록(레포 상대경로 한 줄씩)
emit() { ( cd "$ROOT" && bash "$1" --emit-scanned ); }
guards_list() {  # 락 머리의 `# guards:` 글롭을 git ls-files 로 푼 것
  local globs; globs="$(grep -m1 '^# guards:' "$ROOT/$1" | sed 's/^# guards: *//')"
  # shellcheck disable=SC2086
  ( cd "$ROOT" && set -f && git ls-files -- $globs )
}
check() {  # check <대상 목록 재료 함수 접두> — 락마다 F 가 모두 들어 있는지
  local entry lock how list f
  for entry in $LOCKS; do
    lock="${entry%%:*}"; how="${entry##*:}"
    if [ "$how" = emit ]; then list="$(emit "$lock")"; else list="$(guards_list "$lock")"; fi
    [ -n "$list" ] || { no "$lock 의 대상 목록을 얻지 못했다"; continue; }
    for f in $F; do
      if printf '%s\n' "$list" | grep -qxF -- "$f"; then ok "$f 가 $lock 의 대상에 있다"; else no "$f 이 $lock 의 대상에 없다"; fi
    done
  done
}
check

# 변이 대조 — 사본에서 쉬운 말 락의 목록에서 conducting-step-4.md 를 빼면 그 줄이 RED 다
if [ -z "${LOCK_TARGETS_ROOT:-}" ]; then
  MT="$(mktemp -d "${TMPDIR:-/tmp}/lock-targets.XXXXXX")" || { no "mktemp 실패"; finish; exit $?; }
  [ -n "$MT" ] && [ -d "$MT" ] || { no "임시 디렉토리가 없다"; finish; exit 1; }
  trap 'rm -rf "$MT"' EXIT
  ( cd "$ROOT" && git ls-files -z | while IFS= read -r -d '' p; do [ -L "$p" ] && continue; mkdir -p "$MT/$(dirname "$p")"; cp "$p" "$MT/$p"; done )
  sed -i.bak 's# plugins/spec-distill/references/conducting-step-4.md##' "$MT/plugins/spec-distill/tests/test_plain_gate_templates.sh"
  rm -f "$MT/plugins/spec-distill/tests/test_plain_gate_templates.sh.bak"
  (cd "$MT" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1)
  OUT="$(LOCK_TARGETS_ROOT="$MT" bash "$ROOT/shared/tests/test_conducting_lock_targets.sh" 2>&1 || true)"
  assert_contains "$OUT" "conducting-step-4.md 이 plugins/spec-distill/tests/test_plain_gate_templates.sh 의 대상에 없다" "변이 대조: 목록에서 step-4 를 빼면 그 줄이 RED"
fi
finish
