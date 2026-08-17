#!/usr/bin/env bash
# test_qg_publish_offer.sh — qg.md post-pipeline publish offer (v2.10.0).
# Static doc-lock: the offer block, its Skill delegation, the /qg-publish floor,
# and AskUserQuestion in allowed-tools. Section-scoped + body-unique (teeth).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# (1) allowed-tools includes AskUserQuestion (offer 발동용).
AT="$(awk '/^allowed-tools:/{print; exit}' "$CMD")"
grep -q 'AskUserQuestion' <<<"$AT" && ok "allowed-tools includes AskUserQuestion" || no "AskUserQuestion missing from allowed-tools"

# Section window: '### After the pipeline' 부터 다음 '###'/'##' 헤더 전까지만
# (body-unique + header-satisfiable trap 회피).
OFFER="$(awk '/^### After the pipeline/{f=1;print;next} f&&/^#{2,3} /{exit} f{print}' "$CMD")"

# (2) body-unique offer question phrase (헤더에 없음).
grep -qF 'PR-이해글을 생성해서 게시할까요' <<<"$OFFER" && ok "offer question literal present" || no "offer question literal missing"

# (3) "예" 분기가 publish skill로 위임.
grep -qF 'publishing-pr-understanding' <<<"$OFFER" && ok "offer delegates to publish skill" || no "no publish-skill delegation in offer"

# (4) graceful floor: /qg-publish 안내.
grep -qF '/qg-publish' <<<"$OFFER" && ok "offer has /qg-publish floor" || no "no /qg-publish floor in offer"

# (5) kill switch 체크.
grep -qF 'DEVBREW_QG_DISABLE_PUBLISH' <<<"$OFFER" && ok "offer honors DEVBREW_QG_DISABLE_PUBLISH" || no "kill switch not checked in offer"

# (6) sentinel 유효성(마커) 체크.
grep -qF 'publish-eligible.md' <<<"$OFFER" && ok "offer checks publish-eligible sentinel" || no "sentinel presence not checked in offer"

# (6b) marker-VALIDITY gate: the offer must require the sentinel's first line to
# be the EXACT v1 marker, not merely that a file named publish-eligible.md
# exists — else any file with that name would arm the fail-safe. Section-scoped
# to the OFFER window + body-unique literal (this marker id is not in a header).
grep -qF 'qg-publish-eligible:v1' <<<"$OFFER" && ok "offer requires the exact v1 sentinel marker (validity gate)" || no "marker-validity gate missing from offer (filename presence alone is insufficient)"

# (7) GLOBAL kill switch 체크 (offer must ALSO honor DEVBREW_DISABLE_QUALITY_GATES —
# setup-qg.sh exits at its own global-kill check before reaching its stale-sentinel
# delete, so a stale sentinel from a prior same-session run can survive; the offer
# must not fire on that stale sentinel when the global switch is set). Scoped to
# the OFFER window + body-unique (this literal doesn't appear in a header).
grep -qF 'DEVBREW_DISABLE_QUALITY_GATES' <<<"$OFFER" && ok "offer honors DEVBREW_DISABLE_QUALITY_GATES (global kill)" || no "global kill switch not checked in offer"
finish
