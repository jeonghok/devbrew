#!/usr/bin/env bash
# 인라인 python 호출은 `-I` 로 격리한다 — 리포 전체 락.
#
# `python3 -c` · `-m` · `-` · heredoc · 파이프로 부르면 현재 디렉토리가 sys.path 맨 앞이라, 플러그인이
# 리뷰 · 감사 대상 리포 안에서 돌 때 그 리포의 json.py · uuid.py 가 표준 모듈 대신 실행된다.
# 두 겹으로 잰다.
#   정적 — 추적되는 플러그인 · shared · tools 파일의 인라인 호출 전부에 -I 가 있다(예외는 사유와 함께).
#   행동 — 표준 모듈 이름의 파일을 심은 리포에서 진입 스크립트를 돌려도 그 파일이 실행되지 않는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=assert.sh
. "$ROOT/shared/tests/assert.sh"
SCAN="$ROOT/shared/tests/inline_python_scan.py"

# 일부러 리포 코드를 돌리는 자리 — 경로 · 줄에 들어 있는 글자 · 사유. 줄이 사라지면 그 예외도 지운다.
EXEMPT_PATHS=(
  "plugins/quality-gates/scripts/run-test-selection.sh"
  "plugins/plugin-audit/scripts/run-own-tests.sh"
)
EXEMPT_NEEDLES=(
  "python3 -m venv .venv"
  "python3 -m unittest discover"
)
EXEMPT_REASONS=(
  "차등 테스트의 venv setup 명령 — 리뷰 대상 리포의 setup 을 일부러 돌린다(R22 kill switch 가 막는다)"
  "감사 대상 플러그인의 자체 테스트를 샌드박스에서 일부러 돌린다(README 의 알려진 한계)"
)

note "[분류기 — 꼴마다 하나]"
check() {  # check <줄> <기대>
  local got
  got="$(printf '%s\n' "$1" | python3 -I "$SCAN" classify)"
  assert_eq "$got" "$2" "분류: $1"
}
check "x=\$(python3 -c 'import json')" inline-bare
check "python3 -I -c 'import json'" inline-isolated
check "python3 -Ic 'import json'" inline-isolated
check "python3 -B -c 'import json'" inline-bare
check "python3 -m unittest discover" inline-bare
check "python3 -I -m json.tool" inline-isolated
check "GIT_OPTIONAL_LOCKS=0 python3 - \"\$out\" <<'PY'" inline-bare
check "python3 -I - \"\$out\" <<'PY'" inline-isolated
check "printf x | python3 -c 'import sys'" inline-bare
check "cat f | python3" inline-bare
check "python3 <<'EOF'" inline-bare
check "python3 >out.txt" inline-bare
check "/usr/bin/python3 -c 'pass'" inline-bare
check ".venv/bin/python -m pip install -q" inline-bare
check "python -c 'pass'" inline-bare
check "python3.11 -c 'pass'" inline-bare
check "python3 -W ignore -c 'pass'" inline-bare
check "python3 \"\$QG/scripts/verdict.py\" --line" script
check "python3 -I \"\$QG/scripts/verdict.py\"" script
check "python3 -B foo.py -c" script
check "command -v python3 >/dev/null" none
check "echo \"python3 가 없어 건너뛴다\"" script
check "export PYTHONPATH=x" none
check "run_python3 -c x" none
check "set +B  # nested \"\$(python3 -c \"...\")\"" none
check "\`\`\`python" none
check "echo 'a # b' | python3 -c 'pass'" inline-bare

note "[정적 — 추적되는 파일의 인라인 호출]"
corpus=()
while IFS= read -r -d '' p; do
  case "$p" in
    */tests/*|*/CHANGELOG.md|*/README.md) continue ;;
  esac
  corpus+=("$ROOT/$p")
done < <(git -C "$ROOT" ls-files -z -- plugins shared tools)
assert_eq "$([ "${#corpus[@]}" -ge 200 ] && echo ok || echo "${#corpus[@]}")" ok "코퍼스가 비지 않았다(파일 ${#corpus[@]}개)"

report="$(python3 -I "$SCAN" scan "${corpus[@]}")"
bare="$(printf '%s\n' "$report" | awk -F'\t' '$2 == "bare"')"
left="$bare"
for i in "${!EXEMPT_PATHS[@]}"; do
  hit="$(printf '%s\n' "$bare" | grep -F "$ROOT/${EXEMPT_PATHS[$i]}:" | grep -F -- "${EXEMPT_NEEDLES[$i]}")"
  assert_eq "$(printf '%s' "$hit" | grep -c .)" 1 "예외가 아직 한 줄을 가리킨다: ${EXEMPT_PATHS[$i]} — ${EXEMPT_REASONS[$i]}"
  left="$(printf '%s\n' "$left" | grep -vF -- "$hit")"
done
left="$(printf '%s\n' "$left" | grep .)"
if [ -z "$left" ]; then
  ok "격리 없는 인라인 python 호출이 없다(예외 ${#EXEMPT_PATHS[@]}개 제외)"
else
  no "격리 없는 인라인 python 호출 — python3 -I 로 부른다"
  printf '%s\n' "$left" | sed "s#^$ROOT/#      #"
fi

note "[정적 — 양성 증인: 고친 자리를 스캐너가 인라인 · 격리로 본다]"
for f in \
  plugins/quality-gates/scripts/setup-qg.sh \
  plugins/quality-gates/scripts/discover-spec.sh \
  plugins/quality-gates/scripts/e2e-state.sh \
  plugins/quality-gates/scripts/publish-comment.sh \
  plugins/quality-gates/scripts/run-test-selection.sh \
  plugins/plugin-audit/scripts/check-plugin-structure.sh \
  plugins/plugin-audit/scripts/run-own-tests.sh \
  plugins/spec-distill/skills/request-framing/SKILL.md \
  plugins/spec-distill/skills/reviewing-brief/SKILL.md \
  plugins/spec-distill/skills/spec-review/SKILL.md \
  shared/docreview/scripts/run_docreview_codex_reviewer.sh; do
  n="$(printf '%s\n' "$report" | awk -F'\t' -v p="$ROOT/$f:" 'index($1, p) == 1 && $2 == "isolated"' | grep -c .)"
  assert_eq "$([ "$n" -ge 1 ] && echo ok || echo 0)" ok "$f — 격리된 인라인 호출 ${n}개"
done

note "[행동 — 표준 모듈 이름을 심은 리포]"
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"; MARK="$TMP/planted-ran"
mkdir -p "$REPO/docs" "$REPO/plug/.claude-plugin"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com; git -C "$REPO" config user.name t
printf '# 캐너리 스펙\n' > "$REPO/docs/spec.md"
printf '{"name":"plug","version":"0.0.1","description":"x"}\n' > "$REPO/plug/.claude-plugin/plugin.json"
git -C "$REPO" commit -q --allow-empty -m "chore: base"
git -C "$REPO" branch -M main
git -C "$REPO" checkout -q -b feature/canary
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "feat: canary" -m "Spec: docs/spec.md"
for m in json socket hashlib subprocess pathlib uuid shutil contextlib importlib re tempfile stat; do
  printf 'import os as _o\nopen(_o.environ["QG_CANARY"], "a").write("%s\\n")\nraise SystemExit(97)\n' "$m" > "$REPO/$m.py"
done
export QG_CANARY="$MARK"
planted() { [ -s "$MARK" ] && tr '\n' ' ' < "$MARK" || echo "(없음)"; }

(cd "$REPO" && python3 -c 'import json' >/dev/null 2>&1)
assert_eq "$(planted)" "json " "양성 대조 — 격리 없는 python3 -c 는 심은 json.py 를 실행한다"
rm -f "$MARK"

QG="$ROOT/plugins/quality-gates/scripts"
out="$(cd "$REPO" && bash "$QG/discover-spec.sh" --intent-out "$TMP/intent.md" 2>&1)"
assert_contains "$out" '"intent_source": "spec-trailer"' "discover-spec.sh 가 spec 트레일러까지 돌았다"
assert_eq "$(planted)" "(없음)" "discover-spec.sh — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

out="$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=canary-0001 bash "$QG/setup-qg.sh" --session-id canary-0001 2>&1)"; rc=$?
assert_eq "$rc" 0 "setup-qg.sh 가 끝까지 돌았다: $(printf '%s' "$out" | tail -n 1)"
assert_eq "$(planted)" "(없음)" "setup-qg.sh — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

out="$(cd "$REPO" && bash "$QG/e2e-state.sh" fingerprint --out "$TMP/before.txt" 2>&1)"
assert_contains "$out" "fingerprint: $TMP/before.txt" "e2e-state.sh fingerprint 가 지문을 냈다"
out="$(cd "$REPO" && bash "$QG/e2e-state.sh" compare "$TMP/before.txt" "$TMP/before.txt" 2>&1)"
assert_eq "$out" "same" "e2e-state.sh compare 가 같은 지문을 same 으로 냈다"
printf '기대 상태\t판정\t증거\n화면이 뜬다\t충족\t"ok"\n' > "$TMP/ev.tsv"
out="$(cd "$REPO" && bash "$QG/e2e-state.sh" propose "$TMP/ev.tsv" 2>&1)"
assert_contains "$out" "proposal: " "e2e-state.sh propose 가 판정안을 냈다"
assert_eq "$(planted)" "(없음)" "e2e-state.sh — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

PA="$ROOT/plugins/plugin-audit/scripts"
mkdir -p "$TMP/no-plugin-dev"
out="$(cd "$REPO" && bash "$PA/check-plugin-structure.sh" plug --plugin-dev-root "$TMP/no-plugin-dev" 2>&1)"
assert_contains "$out" '"degraded"' "check-plugin-structure.sh 가 결과 JSON 을 냈다"
out="$(cd "$REPO" && bash "$PA/run-own-tests.sh" plug canary-0001 --sandbox-helper "$TMP/absent.sh" 2>&1)"
assert_contains "$out" '"own_tests"' "run-own-tests.sh 가 결과 JSON 을 냈다"
assert_eq "$(planted)" "(없음)" "plugin-audit 두 스크립트 — 심은 모듈이 실행되지 않았다"

finish
