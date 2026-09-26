#!/usr/bin/env bash
# AC2 (v2.13.0) — codex is a Tier B availability-floor: dispatched whenever
# detect_codex is true, regardless of diff scope. SKILL.md prose invariant
# (proxy — real LLM dispatch is manual self-dogfood). Rewritten from the
# pre-2.13.0 `codex_manifest.codex_available == true/false` phase1_agents
# fallback structure, which the scope-driven rewrite removed.
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_REAL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Task 31 fix round 1 (F1): case 5(c5_bad) 는 pre-2.13.0 codex_manifest 폴백 산문이
# "스킬 어디에도" 없다는 전량 불변식이다. 차등 테스트 절차가
# references/differential-test.md 로 옮겨진 뒤에도 그 산문이 거기서 되살아나면 안 되므로,
# 분할 전과 동일한 논리적 문서로 재구성해 그 위에서 돈다. case 1-4의 윈도우 검사는
# 전부 다른 전제 각도(codex) 섹션만 앵커하므로 영향받지 않는다.
# 재구성 실패는 조용히 원본으로 폴백하지 않고 FAIL 한다.
. "$REPO_ROOT/plugins/quality-gates/tests/lib/reconstruct-skill.sh"
if ! SKILL="$(reconstruct_skill_md "$SKILL_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/differential-test.md 재구성 실패 ($SKILL_REAL)"
  exit 1
fi
trap 'rm -f "$SKILL"' EXIT

# 1. 다른 전제 각도(codex) prose present (body-unique anchor).
if grep -qF '다른 전제 각도 — codex (사용 가능하면 부른다' "$SKILL"; then
  ok "1: 다른 전제 각도(codex) anchor present"
else
  no "1: SKILL missing 다른 전제 각도(codex) anchor"
fi

# 2. codex is scope-independent (dispatched regardless of scope when available).
#    Anchor the 'regardless of scope' claim within the codex-angle window (codex
#    anchor → next '**추가 리뷰어' or '## ' heading) so it can't be satisfied by the
#    security-angle line.
tb_start=$(awk '/다른 전제 각도 — codex \(사용 가능하면 부른다/{print NR; exit}' "$SKILL")
tb_end=$(awk -v s="$tb_start" 'NR>s && (/\*\*추가 리뷰어/ || /^## /){print NR; exit}' "$SKILL")
if [[ -n "$tb_start" && -n "$tb_end" ]] && awk -v s="$tb_start" -v e="$tb_end" 'NR>=s && NR<e' "$SKILL" | grep -qF 'regardless of scope'; then
  ok "2: codex dispatch is scope-independent (in codex-angle window $tb_start..$tb_end)"
else
  no "2: codex-angle window lacks a scope-independence claim (s=$tb_start e=$tb_end)"
fi

# 3. codex dispatched via run_codex_reviewer.sh (script-based, T3-3 unchanged).
if grep -qF 'run_codex_reviewer.sh' "$SKILL"; then
  ok "3: run_codex_reviewer.sh invocation present"
else
  no "3: SKILL missing run_codex_reviewer.sh invocation"
fi

# 4. Floor dispatch blocks still thread project_dir (contract preserved through rewrite).
# PR4a: adversarial dropped from this loop — it was deleted and its replacement
# (doc-recritic, Phase 1.5) has no project_dir dispatch slot by design (the
# coordinate rides inside <document>, not a separate field).
c4_bad=0
for name in security-reviewer; do
  awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+12 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL" || { c4_bad=1; no "4: floor dispatch block for $name lacks project_dir within 12 lines"; }
done
[ "$c4_bad" -eq 0 ] && ok "4: floor dispatch block (security-reviewer) threads project_dir"

# 5. Negative: the removed pre-2.13.0 fallback structure must be GONE.
c5_bad=0
for stale in 'codex_manifest.codex_available == false' 'codex_manifest.codex_available == true'; do
  if grep -qF "$stale" "$SKILL"; then
    c5_bad=1
    no "5: stale pre-2.13.0 codex_manifest prose still present — '$stale'"
  fi
done
[ "$c5_bad" -eq 0 ] && ok "5: stale codex_manifest fallback prose absent (scope-driven rewrite)"

finish
