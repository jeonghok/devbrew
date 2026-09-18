#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/templates/interview-seed-audit-template.md shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_anchor.py
#
# seed 프로필이 앵커 부류를 비운 것이 **실제로 처분을 보존하는가**를 헤딩 없는 문서 한 라운드로
# 잰다(설계 2026-09-16-framing-intent-drift §10-1 · AC3). 양성 대조로 같은 라운드를
# `protected_headings: ["*"]` 판본에서도 돌린다 — 그쪽에서 셋이 전부 `decide` 로 올라가야 라우팅이
# 살아 있다는 증거다. 한쪽만 재면 「라우팅이 죽어서 아무것도 안 바뀐다」와 구별되지 않는다.
# 그리고 프로필의 결정 기록 헤딩이 audit 템플릿에 실재하는가(AC8 — 엔진은 없는 헤딩을 파일 끝에
# 새로 만든다. 그 절이 템플릿에 없으면 결정 기록이 degrade 절 뒤에 흩어진다).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/docreview-profiles/seed.md"
  echo "plugins/spec-distill/templates/interview-seed-audit-template.md"
  echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_state.py"
  echo "shared/docreview/scripts/docreview_anchor.py"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
PROF="$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md"
TMP="$(mktemp -d -t sd-seed-prof-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

printf -- '---\ntype: interview-seed\nnext_phase: spec-distill:interview\naudit_file: s.audit.md\n---\n\n로그인이 가끔 실패한다.\n\n다시 검증할 것 — 경합은 의심이다.\n' > "$TMP/s.md"
cat > "$TMP/critic.txt" <<'EOF'
```docreview-layer1
- ref: c1
  category: unfounded_addition
  anchor: "#__doc__"
  disposition: drop
  summary: "PROBE_DROP 탐지기가 스스로 버린 지적"
- ref: c2
  category: premature_closure
  anchor: "#__doc__"
  disposition: ask
  summary: "PROBE_ASK 사용자에게 물어야 하는 열림"
- ref: c3
  category: inference_as_decision
  anchor: "#__doc__"
  disposition: fix
  summary: "PROBE_FIX 추론이 결정처럼 쓰였다"
```
```docreview-layer2
[]
```
EOF

route() {   # route <profile> <tag> → PROBE_DROP · PROBE_ASK · PROBE_FIX 의 최종 처분을 한 줄로
  local prof="$1" d="$TMP/$2"; mkdir -p "$d"
  python3 "$S/docreview_state.py" init --state-dir "$d" --doc "$TMP/s.md" --profile "$prof" >/dev/null || { echo INIT_FAIL; return; }
  python3 "$S/docreview_anchor.py" snapshot "$TMP/s.md" > "$d/snap.json"
  python3 "$S/docreview_state.py" begin-round --state-dir "$d" --snapshot "$d/snap.json" >/dev/null || { echo BEGIN_FAIL; return; }
  cp "$TMP/critic.txt" "$d/critic.txt"   # 라운드 시작 «뒤»에 쓴다 — 앞이면 critic_predates_round
  python3 "$S/docreview_route.py" prepare-recritic --state-dir "$d" --critic "$d/critic.txt" > "$d/prep.json" || { echo PREP_FAIL; return; }
  python3 "$S/docreview_route.py" finalize --state-dir "$d" --recritic-skipped --doc "$TMP/s.md" > "$d/fin.json" || { echo FIN_FAIL; return; }
  python3 - "$d/fin.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
by = {}
for f in d.get("findings") or []:
    for tag in ("PROBE_DROP", "PROBE_ASK", "PROBE_FIX"):
        if tag in (f.get("summary") or ""):
            by[tag] = f.get("disposition")
print(" ".join(by.get(t, "MISSING") for t in ("PROBE_DROP", "PROBE_ASK", "PROBE_FIX")))
PY
}

# ── AC3 — 앵커 부류를 비운 프로필 ─────────────────────────────────────────────
assert_eq "$(route "$PROF" empty)" "drop ask fix" \
  "AC3: seed 프로필(앵커 부류 비움)에서 drop · ask · fix 가 그대로 배달된다 — 개수 공시로 충분한 drop 이 사용자 앞으로 올라오지 않는다"

# ── 양성 대조 — 보호를 켠 판본에서는 셋 다 decide ─────────────────────────────
sed 's/^protected_headings: \[\]$/protected_headings: ["*"]/' "$PROF" > "$TMP/seed-protected.md"
if grep -q '^protected_headings: \["\*"\]$' "$TMP/seed-protected.md"; then
  assert_eq "$(route "$TMP/seed-protected.md" protected)" "decide decide decide" \
    "양성 대조: protected_headings [\"*\"] 면 셋 다 decide — 이 라우팅은 살아 있다(위 GREEN 이 공허하지 않다)"
else
  no "양성 대조 변이가 적용되지 않았다 — seed 프로필의 protected_headings 줄 모양이 바뀌었다"
fi

# ── AC8 — 결정 기록 헤딩이 템플릿에 실재 ──────────────────────────────────────
heading="$(python3 "$S/docreview_state.py" profile-check "$PROF" | python3 -c 'import json,sys; print(json.load(sys.stdin)["decision_log"]["heading"])')"
assert_eq "$heading" "## 6. 리뷰 결정" "AC8: seed 프로필의 decision_log 헤딩"
assert_eq "$(grep -cxF "$heading" "$TPL")" "1" "AC8: 그 헤딩이 audit 템플릿에 정확히 한 번 있다(엔진이 파일 끝에 새로 만들지 않는다)"
finish
