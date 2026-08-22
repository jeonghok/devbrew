#!/usr/bin/env bash
# test_qg_publish_offer.sh — qg.md post-pipeline publish offer (v2.10.0).
# Static doc-lock: the offer block, its Skill delegation, the /qg-publish floor,
# and AskUserQuestion in the offer window. Section-scoped + body-unique (teeth).
#
# 2026-08-22: `allowed-tools:` frontmatter key removed repo-wide from commands —
# 헤드리스 실측 5변형이 그 선언은 아무것도 집행하지 않음을 확정했다(CLAUDE.md
# 참고). AskUserQuestion 단언 대상을 그 죽은 선언에서 offer 섹션 본문(OFFER 창)
# 으로 옮긴다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# Section window: '### After the pipeline' 부터 다음 '###'/'##' 헤더 전까지만
# (body-unique + header-satisfiable trap 회피). 아래 모든 단언보다 먼저 도출한다.
OFFER="$(awk '/^### After the pipeline/{f=1;print;next} f&&/^#{2,3} /{exit} f{print}' "$CMD")"

# (1) offer 창이 실제로 AskUserQuestion(...) 호출을 담고 있는가(offer 발동용).
grep -qF 'AskUserQuestion' <<<"$OFFER" && ok "offer window invokes AskUserQuestion" || no "AskUserQuestion missing from offer window"

# (2) body-unique offer question phrase (헤더에 없음).
grep -qF 'PR-이해글을 생성해서 게시할까요' <<<"$OFFER" && ok "offer question literal present" || no "offer question literal missing"

# (3) "예" 분기가 publish skill로 위임.
grep -qF 'publishing-pr-understanding' <<<"$OFFER" && ok "offer delegates to publish skill" || no "no publish-skill delegation in offer"

# (4) graceful floor: /qg-publish 안내.
grep -qF '/qg-publish' <<<"$OFFER" && ok "offer has /qg-publish floor" || no "no /qg-publish floor in offer"

# (5) kill switch 체크.
grep -qF 'DEVBREW_QUALITY_GATES_DISABLE_PUBLISH' <<<"$OFFER" && ok "offer honors DEVBREW_QUALITY_GATES_DISABLE_PUBLISH" || no "kill switch not checked in offer"

# (6) sentinel 유효성(마커) 체크.
grep -qF 'publish-eligible.md' <<<"$OFFER" && ok "offer checks publish-eligible sentinel" || no "sentinel presence not checked in offer"

# (6b) marker-VALIDITY gate: the offer must require the sentinel's first line to
# be the EXACT v1 marker, not merely that a file named publish-eligible.md
# exists — else any file with that name would arm the fail-safe. Section-scoped
# to the OFFER window + body-unique literal (this marker id is not in a header).
grep -qF 'qg-publish-eligible:v1' <<<"$OFFER" && ok "offer requires the exact v1 sentinel marker (validity gate)" || no "marker-validity gate missing from offer (filename presence alone is insufficient)"

# (7) GLOBAL kill switch 체크 (offer must ALSO honor DEVBREW_QUALITY_GATES_DISABLE —
# setup-qg.sh exits at its own global-kill check before reaching its stale-sentinel
# delete, so a stale sentinel from a prior same-session run can survive; the offer
# must not fire on that stale sentinel when the global switch is set). Scoped to
# the OFFER window + body-unique (this literal doesn't appear in a header).
grep -qF 'DEVBREW_QUALITY_GATES_DISABLE' <<<"$OFFER" && ok "offer honors DEVBREW_QUALITY_GATES_DISABLE (global kill)" || no "global kill switch not checked in offer"
finish
