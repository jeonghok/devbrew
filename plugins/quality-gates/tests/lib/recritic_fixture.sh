# shellcheck shell=bash
# recritic_fixture.sh — 합성기를 재비판 경로(`--recritic`)로 부르는 테스트 헬퍼.
# `source` 해서 쓴다. 호출자가 PLUGIN_ROOT 를 정해 둬야 한다.
#
#   rf_prep  <dir>           <dir>/findings.yaml → <dir>/rf.yaml · <dir>/map.json
#   rf_reply <dir> <block>   <dir>/reply.txt — 재비판자 응답 원문(산문 + 펜스 하나)
#   rf_synth <dir> [인자...] 합성기를 재비판 경로로 부른다(stdout · rc 그대로)
#
# 판정은 `f<n>` 으로 적는다 — n 은 findings.yaml 안 «매핑 항목»의 1-기반 순번이다
# (recritic_bridge.anonymize 가 그 순서로 번호를 준다).
rf_prep() {
  python3 "$PLUGIN_ROOT/scripts/recritic_bridge.py" prepare --findings "$1/findings.yaml" \
    --out-findings "$1/rf.yaml" --out-map "$1/map.json"
}
rf_reply() {
  { printf '재비판을 마쳤습니다.\n\n```docreview-recritic\n'; printf '%s\n' "$2"; printf '```\n'; } > "$1/reply.txt"
}
rf_synth() {
  local d="$1"; shift
  python3 "$PLUGIN_ROOT/scripts/synthesize_findings.py" --findings "$d/findings.yaml" \
    --recritic "$d/reply.txt" --recritic-map "$d/map.json" "$@"
}
