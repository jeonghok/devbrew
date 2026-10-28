#!/usr/bin/env bash
# guards: plugins/*/skills/*.md plugins/*/references/*.md plugins/*/agents/*.md shared/*/references/*.md shared/tests/ask_recommendation.py shared/tests/fixtures/ask-sites.tsv shared/tests/fixtures/ask_recommendation/*
#
# 질문 자리 추천 표시 전수 검사 — 모델이 읽는 문서에서 `AskUserQuestion` 이 있는 줄(후보 줄)을 도출하고,
# 목록(fixtures/ask-sites.tsv)의 행마다 종류(꼬리 · 지시 · 비움 · 출처꼬리 · 언급 · 떼기)가 요구하는 글자가
# 그 질문의 범위 안에 있는지 본다. 판정은 ask_recommendation.py 가 한다.
#
# 한계 둘:
#  · 모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다.
#  · 도구 이름 없이 문장으로만 묻는 새 질문 자리는 후보로 뽑히지 않는다 — 목록의 손 행은 지금 있는 자리만 덮는다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FX="shared/tests/fixtures/ask_recommendation"
derive_git() {
  git -C "$ROOT" ls-files --cached --others --exclude-standard -- \
    'plugins/*/skills/*.md' 'plugins/*/references/*.md' 'plugins/*/agents/*.md' 'shared/*/references/*.md' \
    | grep -v '/tests/' | LC_ALL=C sort -u \
    | while IFS= read -r f; do [ -L "$ROOT/$f" ] || printf '%s\n' "$f"; done
}
if [ "${1:-}" = "--emit-scanned" ]; then
  derive_git
  printf '%s\n' shared/tests/ask_recommendation.py shared/tests/fixtures/ask-sites.tsv \
    "$FX/doc.md" "$FX/sites.tsv" "$FX/expected.txt"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
LIST="$(mktemp -t askq-list-XXXXXX)" || exit 1
RES="$(mktemp -t askq-res-XXXXXX)" || { rm -f "$LIST"; exit 1; }
FXL="$(mktemp -t askq-fxl-XXXXXX)" || { rm -f "$LIST" "$RES"; exit 1; }
trap 'rm -f "$LIST" "$RES" "$FXL"' EXIT
derive_git > "$LIST"
# 양의 짝 — git 도출(심볼릭 링크 뺌)과 find 도출(보통 파일만)이 같은 수를 낸다. 다르면 ④.
FIND_N="$(cd "$ROOT" && find plugins shared -type f \( -path 'plugins/*/skills/*.md' -o -path 'plugins/*/references/*.md' -o -path 'plugins/*/agents/*.md' -o -path 'shared/*/references/*.md' \) ! -path '*/tests/*' | grep -c .)"
GIT_N="$(grep -c . "$LIST" || true)"
assert_eq "$GIT_N" "$FIND_N" "④ 후보 파일: git 도출과 find 도출이 같은 수를 낸다"
CAND_N="$(cd "$ROOT" && while IFS= read -r f; do grep -F -- 'AskUserQuestion' "$f"; done < "$LIST" | grep -c . || true)"
if [ "${CAND_N:-0}" -gt 0 ]; then ok "④ 후보 줄 ${CAND_N}개(0 이 아니다)"; else no "④ 후보 줄이 0개다 — 공허한 통과"; fi

# fixture — 여섯 경우의 판정이 expected.txt 와 같다(모듈이 RED 넷을 실제로 내는지).
printf '%s\n' doc.md > "$FXL"
FX_OUT="$(python3 "$ROOT/shared/tests/ask_recommendation.py" "$ROOT/$FX" "$FXL" "$ROOT/$FX/sites.tsv" 2>&1)"
fx_rc=$?
assert_eq "$fx_rc" "0" "fixture: 판정 모듈이 rc 0 으로 끝났다"
assert_eq "$(printf '%s\n' "$FX_OUT" | grep '^no ')" "$(cat "$ROOT/$FX/expected.txt")" "fixture: no 줄이 expected.txt 와 같다"
assert_contains "$FX_OUT" 'ok doc.md:5 꼬리 「가-질문:」' "fixture: 라벨 꼬리가 있는 질문은 ok"
# ④ — 후보 파일이 없으면(빈 목록) 모듈은 「no ④」 한 줄만 내고 다른 판정을 하지 않는다.
: > "$FXL"
FX4_OUT="$(python3 "$ROOT/shared/tests/ask_recommendation.py" "$ROOT/$FX" "$FXL" "$ROOT/$FX/sites.tsv" 2>&1)"
assert_eq "$FX4_OUT" "no ④ -:- 후보 줄이 0개다 — 글롭이 아무것도 고르지 않았다(공허한 통과 방지)" "fixture: 후보 0 이면 ④ 한 줄"

python3 "$ROOT/shared/tests/ask_recommendation.py" "$ROOT" "$LIST" "$ROOT/shared/tests/fixtures/ask-sites.tsv" > "$RES" 2>&1
rc=$?
assert_eq "$rc" "0" "판정 모듈이 rc 0 으로 끝났다"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
    *) no "판정 모듈이 알 수 없는 줄을 냈다: $line" ;;
  esac
done < "$RES"
finish
