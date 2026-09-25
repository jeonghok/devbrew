#!/usr/bin/env bash
# test_recritic_bridge.sh — 재비판 변환 계층 (설계 §6.3.4 · §6.3.3 · AC17, PR4a 계획 R-N·R-O·R-P).
#
# 재비판자는 문서 리뷰 엔진의 계약으로 말하고(f · confirm/reject/raise · added) 합성기는
# finding_id · verdicts · new_findings 로 말한다. 이 락은 그 사이의 번역이 **판정을 바꾸는
# 모든 자리를 원장에 남기는지**를 잰다 — 근거 없는 기각 · 매핑 못 하는 to · 모르는 f.
#
# 판정 값을 직접 보는 케이스는 `--emit-verdict` 를 켠다(오케스트레이터는 PR4b 부터 켠다 —
# 이 락은 그 경로를 미리 잰다). 본 보고서만 보는 케이스는 오늘 오케스트레이터가 부르는
# 모양 그대로다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
B="$PLUGIN_ROOT/scripts/recritic_bridge.py"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
export PYTHONDONTWRITEBYTECODE=1

# one_finding <파일> [agent] [file] [line] [severity]
one_finding() {
  printf -- '- agent: %s\n  file: %s\n  line: %s\n  severity: %s\n  confidence: 8\n  summary: "문자열 결합으로 SQL 을 만든다"\n  proposed_fix: "파라미터 바인딩"\n' \
    "${2:-security-reviewer}" "${3:-app.py}" "${4:-10}" "${5:-IMPORTANT}" > "$1"
}

# reply <파일> <블록 본문> — 재비판자 응답 원문 모양(앞 산문 + 펜스 하나)
reply() {
  { printf '재비판을 마쳤습니다.\n\n```docreview-recritic\n'; printf '%s\n' "$2"; printf '```\n'; } > "$1"
}

# prep <디렉토리> — findings.yaml → rf.yaml(익명 목록) + map.json
prep() {
  python3 "$B" prepare --findings "$1/findings.yaml" --out-findings "$1/rf.yaml" --out-map "$1/map.json"
}

# synth <디렉토리> [추가 인자...] — 재비판 경로로 합성
synth() {
  local d="$1"; shift
  python3 "$SYNTH" --findings "$d/findings.yaml" --recritic "$d/reply.txt" --recritic-map "$d/map.json" "$@"
}

case_prepare_strips_source_and_keeps_severity() {
  local T; T=$(mktemp -d)
  printf -- '- agent: security-reviewer\n  file: app.py\n  line: 10\n  severity: IMPORTANT\n  confidence: 8\n  summary: "s"\n  proposed_fix: "p"\n  sources: [security-reviewer, codex]\n' > "$T/findings.yaml"
  local rc=0; prep "$T" || rc=$?
  assert_eq "$rc" "0" "prepare 정상 종료"
  assert_file_grep   "$T/rf.yaml" '^- f: f1$'                 "항목은 f1 로 식별된다"
  assert_file_grep   "$T/rf.yaml" 'disposition: IMPORTANT'    "severity 가 처분 칸으로 간다 (R-O)"
  assert_file_absent "$T/rf.yaml" 'security-reviewer|codex'   "출처(agent · sources)가 지워진다 — 프레이밍 맹목성"
  assert_file_absent "$T/rf.yaml" 'confidence'                "리뷰어의 결론(confidence)이 지워진다"
  local id
  id="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['f1']['finding_id'])" "$T/map.json")"
  assert_eq "$id" "security-reviewer-app.py-10" "역매핑이 합성기의 finding_id 를 준다"
  rm -rf "$T"
}

case_prepare_empty_states_the_empty_slot() {
  # §6.3.3 · AC17 — 탐지 0 이어도 재비판자에게 «비었다는 사실»을 알린다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  local rc=0; prep "$T" || rc=$?
  assert_eq "$rc" "0" "빈 목록도 prepare 정상 종료"
  assert_file_grep "$T/rf.yaml" '^# 탐지 0건 — 이 목록은 비어 있다\.' "빈 슬롯 문장이 목록에 선다"
  local parsed
  parsed="$(python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1])))" "$T/rf.yaml")"
  assert_eq "$parsed" "[]" "빈 슬롯 문장은 주석이라 YAML 값은 빈 목록이다"
  rm -rf "$T"
}

case_prepare_unreadable_findings_is_fail4_without_outputs() {
  local T; T=$(mktemp -d)
  local rc=0
  python3 "$B" prepare --findings "$T/gone.yaml" --out-findings "$T/rf.yaml" --out-map "$T/map.json" 2>/dev/null || rc=$?
  assert_eq "$rc" "4" "finding 파일을 못 읽으면 exit 4"
  if [ -e "$T/rf.yaml" ] || [ -e "$T/map.json" ]; then no "실패 경로가 출력 파일을 남겼다 (원자성)"; else ok "실패 경로는 출력 파일을 남기지 않는다"; fi
  rm -rf "$T"
}

case_identity_parity_with_weird_fields() {
  # 역매핑의 finding_id 가 합성기의 것과 «정규화까지» 같아야 한다. 다르면 모든 판정이
  # 「판정자 부재」로 떨어진다. file 이 목록 · line 이 문자열인 finding 으로 잰다.
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: [a.py]\n  line: "7"\n  severity: IMPORTANT\n  confidence: 8\n  summary: "s"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" '^verdict: defect$' "confirm 된 finding 이 살아남는다"
  assert_not_grep "$out" 'findings-lost'     "정규화 뒤 id 가 맞는다 — 판정자 부재 보류가 없다"
  rm -rf "$T"
}

case_reject_needs_evidence() {
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject
    evidence: "app.py:9 에서 이미 파라미터 바인딩한다"'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: clean$' "근거 있는 기각은 finding 을 지운다"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject'
  out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: defect$'              "근거 없는 기각은 무효다 — finding 이 남는다"
  assert_grep "$out" '판정 degrade'                   "그 강제는 판정을 바꿨으므로 degrade 로 공시된다 (gate=True)"
  rm -rf "$T"
}

case_raise_goes_up_only() {
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: CRITICAL'
  local out; out=$(synth "$T")
  assert_contains "$out" '**Findings:** 1 CRITICAL / 0 IMPORTANT' "raise to CRITICAL 이 severity 를 올린다"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: SUGGESTION'
  out=$(synth "$T")
  assert_contains     "$out" '**Findings:** 0 CRITICAL / 1 IMPORTANT' "하향 raise 는 무시된다"
  assert_not_contains "$out" '판정 degrade'                            "하향 무시는 판정을 안 바꾼다 (gate=False)"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: decide'
  out=$(synth "$T")
  assert_contains "$out" '**Findings:** 0 CRITICAL / 1 IMPORTANT' "매핑 못 하는 to 는 confirm 으로 강제된다"
  assert_contains "$out" '판정 degrade'                            "그 강제는 공시된다 (gate=True)"
  rm -rf "$T"
}

case_unknown_verdict_value_is_coerced_to_confirm() {
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: downgrade'
  local out; out=$(synth "$T")
  assert_contains "$out" '1 IMPORTANT'   "재비판자 어휘 밖의 판정은 confirm 으로"
  assert_contains "$out" '판정 degrade' "그 강제는 공시된다"
  rm -rf "$T"
}

case_misspelled_f_is_held_not_matched() {
  # Review Focus 4 — `f: 1` · `F1` · `f01` 을 f1 로 맞추지 않는다.
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  local bad out
  for bad in '1' 'F1' 'f01'; do
    reply "$T/reply.txt" "verdicts:
  - f: f1
    verdict: reject
    evidence: \"근거\"
  - f: $bad
    verdict: confirm"
    out=$(synth "$T" --emit-verdict)
    assert_grep "$out" '^verdict: not-certified$' "f='$bad' — 모르는 f 는 보류라 clean 이 아니다"
    assert_grep "$out" '^reason: findings-lost$'  "f='$bad' — 사유는 findings-lost"
  done
  rm -rf "$T"
}

case_duplicate_verdicts_for_one_f_are_held() {
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm
  - f: f1
    verdict: reject
    evidence: "근거"'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" 'findings-lost' "같은 f 에 판정 둘이면 어느 쪽도 고르지 않는다"
  rm -rf "$T"
}

case_colliding_ids_with_split_verdicts_are_not_resolved() {
  # Review Focus 2 — 같은 agent·file·line 의 finding 둘은 같은 finding_id 로 접힌다.
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm
  - f: f2
    verdict: reject
    evidence: "근거"'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" 'findings-lost'       "갈린 판정은 조용히 한쪽을 고르지 않는다"
  assert_not_grep "$out" '^verdict: clean$'    "clean 이 아니다"
  rm -rf "$T"
}

case_colliding_ids_with_partial_verdicts_are_not_resolved() {
  # Important 2 (fix round 1, Law 2 fail-open) — 콜라이딩 finding_id 의 f 중 «일부만»
  # 판정되면(다른 f 는 침묵) 그 일부 판정을 전체에 적용하면 안 된다 — 판정 안 된
  # CRITICAL 이 판정된 IMPORTANT 의 기각을 뒤집어쓰고 조용히 사라진다.
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: CRITICAL\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject
    evidence: "근거"'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" 'findings-lost'    "f2 가 침묵이면 f1 의 기각을 전체에 적용하지 않는다"
  assert_not_grep "$out" '^verdict: clean$' "clean 이 아니다 — CRITICAL 이 조용히 사라지지 않는다"
  rm -rf "$T"
}

case_colliding_ids_with_matching_verdicts_are_resolved() {
  # Important 2 의 「동일」 기준 정밀화 — reject 의 evidence 문구가 달라도 verdict
  # 종류가 같으면(둘 다 reject) 콜라이딩 finding_id 에 합쳐 적용한다. 문구까지
  # 토씨 맞추라는 요구가 아니다(컨트롤러 룰링: "same verdict, and same to for raise").
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: CRITICAL\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: reject
    evidence: "근거 하나"
  - f: f2
    verdict: reject
    evidence: "근거 둘 — 문구가 다르다"'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: clean$' "둘 다 reject 면 evidence 문구가 달라도 합쳐 적용된다"
  rm -rf "$T"
}

case_colliding_ids_with_raise_that_differs_per_severity_are_not_resolved() {
  # Important (fix round 2) — 라운드 1 의 서명 비교(원문 v 의 verdict·to)는 «변환
  # 후» 값을 안 봐서, 같은 `raise to` 라도 f 마다 cur_sev 가 달라 실제로는 오르거나
  # (raise 는 위로만) 무시되는 차이를 놓쳤다. Case A — SUGGESTION+CRITICAL 콜라이드,
  # 둘 다 `raise to: IMPORTANT`. SUGGESTION 은 오르고 CRITICAL 은 무시돼야 하는데,
  # 라운드 1은 원문이 같다(둘 다 "raise IMPORTANT")고 보고 오른 쪽의 conv 를 대표로
  # 골라 CRITICAL 까지 IMPORTANT 로 «내려» 버렸다(그 뒤 dedup 이 흡수까지 했다).
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: SUGGESTION\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: CRITICAL\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: IMPORTANT
  - f: f2
    verdict: raise
    to: IMPORTANT'
  local out; out=$(synth "$T")
  assert_contains "$out" '1 CRITICAL' "CRITICAL 은 조용히 내려가지 않고 그대로 남는다"
  out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" 'findings-lost'    "실제로 오른 raise 와 무시된 raise 를 같다고 보지 않는다"
  assert_not_grep "$out" '^verdict: clean$' "clean 이 아니다"
  rm -rf "$T"
}

case_colliding_ids_with_raise_ignored_for_one_severity_are_not_resolved() {
  # Important (fix round 2) Case B — CRITICAL(먼저 f1) + IMPORTANT(f2), 둘 다
  # `raise to: CRITICAL`. f1 은 이미 그 severity 라 raise 가 무시되고(같은 레벨은
  # 「위로 오르는」게 아니다) f2 는 실제로 오른다. 첫 judged 키(무시된 confirm)를
  # 대표로 고르면 IMPORTANT 가 영원히 안 오르고 hold 도 없다.
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: CRITICAL\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: CRITICAL
  - f: f2
    verdict: raise
    to: CRITICAL'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" 'findings-lost'    "무시된 raise 와 실제로 오른 raise 를 같다고 보지 않는다"
  assert_not_grep "$out" '^verdict: clean$' "clean 이 아니다"
  rm -rf "$T"
}

case_colliding_ids_with_raise_to_different_targets_are_not_resolved() {
  # Task 7 row 30 / 컨트롤러 M1 — 콜라이딩 서명 비교가 `verdict` 종류만 보고
  # `adjusted_severity` 를 빼면, 둘 다 «실제로 오른» raise(둘 다 verdict="raise")
  # 인데 «어디까지» 오르는지가 다를 때 서명이 같다고 보고 하나를 골라 합친다 —
  # 더 높이 오른 쪽이 조용히 사라진다(silent raise loss). 기존
  # `..._raise_that_differs_per_severity_...`·`..._raise_ignored_for_one_severity_...`
  # 는 무시된 raise(confirm)와 적용된 raise(raise)가 섞여 있어 verdict 종류만
  # 봐도 이미 다르다 — M1 의 구멍을 못 잡는다. 여기는 둘 다 SUGGESTION 에서
  # 시작해 둘 다 실제로 오르게 만든다(f1 → IMPORTANT, f2 → CRITICAL) — verdict
  # 는 둘 다 "raise" 로 같지만 adjusted_severity 가 다르다.
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: SUGGESTION\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: a.py\n  line: 3\n  severity: SUGGESTION\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: IMPORTANT
  - f: f2
    verdict: raise
    to: CRITICAL'
  local out; out=$(synth "$T")
  assert_contains "$out" '0 CRITICAL / 0 IMPORTANT / 1 SUGGESTION' "둘 다 오른 raise 인데 도착지가 다르면 severity 는 조용히 안 바뀐다 (severity 소실 없음)"
  out=$(synth "$T" --emit-verdict)
  assert_grep     "$out" 'findings-lost'    "verdict 만 같고 adjusted_severity 가 다른 raise 는 합쳐 적용하지 않는다 (보류)"
  assert_not_grep "$out" '^verdict: clean$' "clean 이 아니다"
  rm -rf "$T"
}

case_raise_cannot_lower_when_map_is_stale() {
  # Task 7 row 31 — apply_verdicts 의 raise-only-up guard. bridge 는 자신이 아는
  # cur_sev(map.json 값)로 이미 위인지 검사하지만, map.json 이 스테일하면(실제
  # finding 은 CRITICAL 인데 map 은 옛 값 SUGGESTION 을 쥔 채로) bridge 눈에는
  # 정당한 raise(SUGGESTION→IMPORTANT)인데 실제로는 CRITICAL 을 IMPORTANT 로
  # «내리는» 결과가 나온다. synthesize_findings.py 의 apply_verdicts 가 실제
  # finding 의 (정규화된) severity 와 다시 비교해 막아야 한다.
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml" "scout" "a.py" "3" "CRITICAL"
  prep "$T"
  python3 -c "
import json
p = '$T/map.json'
m = json.load(open(p))
for k in m:
    m[k]['severity'] = 'SUGGESTION'
json.dump(m, open(p, 'w'))
"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: IMPORTANT'
  local out; out=$(synth "$T")
  assert_contains "$out" '1 CRITICAL / 0 IMPORTANT' "스테일 맵이 낮다고 우겨도 실제 CRITICAL 은 안 내려간다"
  out=$(synth "$T" --emit-verdict)
  assert_contains "$out" '판정 degrade' "그 저지는 게이트 강제로 공시된다 (gate=True)"
  rm -rf "$T"
}

case_raise_to_same_severity_is_noop_not_degrade() {
  # 같은 랭크로의 raise(변화 없음)는 gate=False 강제다(bridge 의 같은 사건
  # recritic_bridge.py 의 `ledger.coerced("to", to_raw, cur_sev, gate=False)` 과
  # 같은 모양) — 판정 결과를 안 바꾸므로 degrade 로 공시하면 안 된다. «내리는»
  # raise 만 gate=True(판정 결과를 바꾼다 — CRITICAL 이 내려가는 것을 막았다).
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml" "scout" "a.py" "3" "CRITICAL"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: CRITICAL'
  local out; out=$(synth "$T")
  assert_contains     "$out" '1 CRITICAL / 0 IMPORTANT' "같은 랭크로의 raise 는 severity 를 그대로 둔다"
  assert_not_contains "$out" '판정 degrade' "같은 랭크 강제는 gate=False 다 — degrade 로 공시되지 않는다"
  rm -rf "$T"
}

case_missing_verdict_is_unadjudicated() {
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" 'findings-lost' "재비판자가 건너뛴 항목은 판정자 부재 보류다"
  rm -rf "$T"
}

case_same_as_keeps_both() {
  local T; T=$(mktemp -d)
  printf -- '- agent: scout\n  file: a.py\n  line: 3\n  severity: IMPORTANT\n  confidence: 8\n  summary: "하나"\n- agent: scout\n  file: b.py\n  line: 9\n  severity: IMPORTANT\n  confidence: 8\n  summary: "둘"\n' > "$T/findings.yaml"
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm
  - f: f2
    verdict: confirm
    same_as: [f1]'
  local out; out=$(synth "$T")
  assert_contains     "$out" '0 CRITICAL / 2 IMPORTANT' "same_as 는 코드 경로에서 병합하지 않는다 — 둘 다 산다 (R-O)"
  assert_not_contains "$out" '판정 degrade'             "그 무시는 판정을 안 바꾼다 (gate=False)"
  rm -rf "$T"
}

case_added_becomes_promoted_by_doc_recritic() {
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - file: lib.py
    line: 4
    severity: CRITICAL
    summary: "놓친 경로 탐색"
    proposed_fix: "정규화 후 비교"'
  local out; out=$(synth "$T")
  assert_contains "$out" '1 CRITICAL'             "added 가 승격된다"
  assert_contains "$out" '| doc-recritic |'       "승격 저자는 doc-recritic 이다 (하드코딩 adversarial 이 아니다)"
  assert_not_contains "$out" '| adversarial |'    "유령 저자가 없다"
  rm -rf "$T"
}

case_added_file_derivation_is_single_file_only() {
  # R-P — 단일-파일 diff 에서만 file 을 도출한다. 여러 파일이면 고르지 않는다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - severity: IMPORTANT
    summary: "파일을 안 적은 신규 발견"'
  printf 'diff --git a/only.py b/only.py\n--- a/only.py\n+++ b/only.py\n@@ -1 +1 @@\n-a\n+b\n' > "$T/one.diff"
  printf 'diff --git a/x.py b/x.py\n--- a/x.py\n+++ b/x.py\n@@ -1 +1 @@\n-a\n+b\ndiff --git a/y.py b/y.py\n--- a/y.py\n+++ b/y.py\n@@ -1 +1 @@\n-a\n+b\n' > "$T/two.diff"
  local out
  out=$(synth "$T" --recritic-diff "$T/one.diff")
  assert_contains "$out" '| only.py:0 |' "단일-파일 diff 면 그 파일로 도출한다"
  out=$(synth "$T" --recritic-diff "$T/two.diff")
  assert_contains "$out" '| 미지:0 |'    "여러 파일이면 고르지 않고 미지다"
  out=$(synth "$T")
  assert_contains "$out" '| 미지:0 |'    "diff 가 없으면 미지다"
  rm -rf "$T"
}

case_recritic_zero_is_stated() {
  # AC17 — 탐지 0 · 재비판 0 이 산출물에 명시된다. 침묵과 0 은 다른 사실이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added: []'
  local out; out=$(synth "$T" --emit-verdict)
  assert_contains "$out" '탐지 0 · 재비판 0 — 재비판자가 돌았고 더한 finding 이 없다.' "탐지 0 · 재비판 0 이 명시된다"
  assert_grep     "$out" '^verdict: clean$' "그 실행은 clean 이다"
  # 대조 — 판정자를 안 쓴 실행에는 이 줄이 없다(재비판자가 돈 사실이 아니다)
  out=$(python3 "$SYNTH" --findings "$T/findings.yaml")
  assert_not_contains "$out" '탐지 0 · 재비판 0' "재비판 경로가 아니면 그 줄을 싣지 않는다"
  rm -rf "$T"
}

case_recritic_zero_not_claimed_when_added_is_suppressed_or_broken() {
  # AC17 의 음의 짝 — 재비판자가 `added` 를 냈다면, 그것이 억제되거나(conf ≤ 4 비-CRITICAL)
  # 파손돼 표에 안 실려도 「재비판 0」이 아니다. 모의 실행 변이 20(`not new_raw` 항 제거)이
  # GREEN 이었다: kept > 0 인 케이스만 있어서 빈 분기를 태우지 못했다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - file: lib.py
    line: 4
    severity: SUGGESTION
    confidence: 3
    summary: "약한 신규 발견"'
  local out; out=$(synth "$T")
  assert_contains     "$out" 'No high-confidence findings. 1 low-confidence' "억제된 added 가 억제로 세어진다 (전제)"
  assert_not_contains "$out" '탐지 0 · 재비판 0'                           "억제된 added 가 있으면 재비판 0 이 아니다"
  reply "$T/reply.txt" 'verdicts: []
added:
  - file: lib.py
    severity: IMPORTANT'
  out=$(synth "$T" 2>/dev/null)
  assert_contains     "$out" 'dropped as malformed'   "summary 없는 added 는 파손으로 세어진다 (전제)"
  assert_not_contains "$out" '탐지 0 · 재비판 0'      "파손된 added 가 있어도 재비판 0 이 아니다"
  rm -rf "$T"
}

case_recritic_zero_not_claimed_when_added_or_verdicts_are_malformed() {
  # Important 1 (fix round 1) — recritic_zero 는 «변환 후» 빈 목록만 봐서, 보류·파손된
  # 원본까지 0 으로 접었다(P1·P3). 재비판자가 «무언가를 냈는데» 전부 버려진 것은
  # 재비판 0 이 아니다 — bridge 가 raw verdicts/added 길이를 doc 에 실어 합성기가 본다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - "CRITICAL: missed path traversal in lib.py"'
  local out; out=$(synth "$T" 2>/dev/null)
  assert_not_contains "$out" '탐지 0 · 재비판 0' "P1 — 매핑이 아닌 added 항목이 있으면 재비판 0 이 아니다"
  reply "$T/reply.txt" 'verdicts:
  - f: nope
    verdict: confirm
added: []'
  out=$(synth "$T" 2>/dev/null)
  assert_not_contains "$out" '탐지 0 · 재비판 0' "P3 — 모르는 f 뿐인 verdicts 가 있으면 재비판 0 이 아니다"
  rm -rf "$T"
}

case_added_severity_case_folds() {
  # Minor 4 (fix round 1) — `added.severity` 는 `_norm_sev` 와 같은 규율로 대소문자를
  # 접는다. 접지 않으면 정당한 CRITICAL 이 미지로 강등된다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - file: lib.py
    line: 4
    severity: Critical
    summary: "대소문자 섞인 severity"'
  local out; out=$(synth "$T")
  # fix round 2 (Minor, 이빨 없음 정리) — "미지" 는 이 stdout 에 절대 리터럴로
  # 안 뜬다: 접지 «않아도» severity 는 bridge 에서 UNKNOWN("미지")으로 강제된
  # 뒤 render() 의 `_norm_sev` 가 그 문자열을 다시 SUGGESTION 으로 접어버린다
  # (`_norm_sev` 는 어휘 밖 값을 전부 SUGGESTION 으로 낸다) — "not-contains 미지"
  # 는 접든 안 접든 항상 참이라 대소문자 접기의 증인이 못 된다. 증인은
  # "1 CRITICAL"(접으면 CRITICAL 로 남고, 안 접으면 SUGGESTION 으로 떨어진다) 뿐이다.
  assert_contains "$out" '1 CRITICAL' "대소문자 섞인 severity 도 CRITICAL 로 접힌다"
  rm -rf "$T"
}

case_raise_to_case_folds() {
  # Minor 4 (fix round 1) — raise 의 `to` 도 같은 규율로 대소문자를 접는다.
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: critical'
  local out; out=$(synth "$T")
  assert_contains "$out" '**Findings:** 1 CRITICAL / 0 IMPORTANT' "소문자 to 도 raise 를 적용한다"
  rm -rf "$T"
}

case_added_falls_back_to_disposition_when_severity_missing() {
  # Minor 5 (fix round 1) — 익명 목록은 severity 를 disposition: 으로 싣는다. 재비판자
  # persona 가 같은 모양을 되돌려주면 severity 가 없어도 disposition 을 대신 잡는다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  reply "$T/reply.txt" 'verdicts: []
added:
  - file: lib.py
    line: 4
    disposition: CRITICAL
    summary: "severity 대신 disposition 으로 돌아왔다"'
  local out; out=$(synth "$T")
  # fix round 2 — 같은 이유로 "not-contains 미지" 를 뺐다(case_added_severity_case_folds
  # 참조): `_norm_sev` 가 미판별 값을 전부 SUGGESTION 으로 접어 stdout 에 "미지"가
  # 리터럴로 뜰 일이 없다. 증인은 "1 CRITICAL" 뿐이다.
  assert_contains "$out" '1 CRITICAL' "severity 가 없으면 disposition 으로 대신 잡는다"
  rm -rf "$T"
}

case_dead_recritic_is_not_clean() {
  # 부채 A 의 재비판 경로판 — 응답 파일 없음 · 펜스 없음 · YAML 파손 · 매핑 파일 없음.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  local out rc
  rm -f "$T/reply.txt"
  out=$(synth "$T" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: angle-absent$' "응답 파일이 없으면 판정 각도 부재다"
  printf '결과 없음\n' > "$T/reply.txt"
  out=$(synth "$T" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: angle-absent$' "펜스가 없으면 판정 각도 부재다"
  reply "$T/reply.txt" 'verdicts: ['
  out=$(synth "$T" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: angle-absent$' "블록 YAML 이 깨지면 판정 각도 부재다"
  reply "$T/reply.txt" 'verdicts: []'
  rc=0
  out=$(python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "$T/reply.txt" --recritic-map "$T/gone.json" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "매핑 파일 부재는 호출 오류가 아니다"
  assert_grep "$out" '^reason: angle-absent$' "매핑이 없으면 아무것도 판정되지 않았다 — 판정 각도 부재"
  # 오늘 오케스트레이터가 보는 본 보고서에도 막힘이 보인다(R-R — fail-closed 가 사실이다)
  rm -f "$T/reply.txt"
  out=$(synth "$T" 2>/dev/null)
  assert_contains "$out" '**이 실행은 clean이 아니다**' "--emit-verdict 없이도 not-clean 마커가 선다"
  rm -rf "$T"
}

case_malformed_map_entry_is_dead_adjudicator() {
  # Important 3 (fix round 1) — 역매핑 항목이 손상되면 방어 없는 첨자가 TypeError·
  # ValueError·KeyError 로 traceback(exit 1)을 낸다. 주 입력 실패로 바꾼다.
  #
  # findings 는 비워 둔다(다른 dead-adjudicator 케이스와 같은 모양) — kept=0 이라야
  # `decide()` 가 `defect` 보다 먼저 `not-certified`/`reason: angle-absent` 로
  # 떨어진다. 검증 대상은 map.json 자신의 형태이므로 findings 내용과 무관하다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  local out rc

  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm'
  printf '{"f1": "security-reviewer-app.py-10"}' > "$T/map.json"
  rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "역매핑 항목이 매핑이 아니다 — rc 0 (traceback 아님)"
  assert_grep "$out" '^reason: angle-absent$' "역매핑 항목이 매핑이 아니면 판정자 사망이다"

  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: raise
    to: CRITICAL'
  printf '{"f1": {"finding_id": "security-reviewer-app.py-10", "severity": "HIGH"}}' > "$T/map.json"
  rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "역매핑 severity 가 어휘 밖 — rc 0 (traceback 아님)"
  assert_grep "$out" '^reason: angle-absent$' "역매핑 severity 가 어휘 밖이면 판정자 사망이다"

  printf '{"f1": {"finding_id": "security-reviewer-app.py-10"}}' > "$T/map.json"
  rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "역매핑에 severity 키가 없다 — rc 0 (traceback 아님)"
  assert_grep "$out" '^reason: angle-absent$' "역매핑에 severity 키가 없으면 판정자 사망이다"

  printf '{"f1": {"severity": "IMPORTANT"}}' > "$T/map.json"
  rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "역매핑에 finding_id 키가 없다 — rc 0 (traceback 아님)"
  assert_grep "$out" '^reason: angle-absent$' "역매핑에 finding_id 키가 없으면 판정자 사망이다"
  rm -rf "$T"
}

case_truncated_block_is_dead_adjudicator() {
  # Review Focus 3 — 닫는 펜스가 없는 응답은 블록 «없음»이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  printf '재비판입니다.\n\n```docreview-recritic\nverdicts: []\n' > "$T/reply.txt"
  local out; out=$(synth "$T" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: angle-absent$' "잘린 응답은 재비판 0 이 아니라 판정자 사망이다"
  assert_not_contains "$out" '탐지 0 · 재비판 0' "잘린 응답을 재비판 0 으로 말하지 않는다"
  rm -rf "$T"
}

case_last_block_wins() {
  # Review Focus 1 — 펜스가 둘이면 마지막이 이긴다(docreview_route.extract_block).
  local T; T=$(mktemp -d); one_finding "$T/findings.yaml"; prep "$T"
  { printf '예시:\n```docreview-recritic\nverdicts:\n  - f: f1\n    verdict: reject\n    evidence: "예시"\n```\n\n실제 판정:\n'
    printf '```docreview-recritic\nverdicts:\n  - f: f1\n    verdict: confirm\n```\n'; } > "$T/reply.txt"
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: defect$' "마지막 블록(confirm)이 판정이다 — 인용한 예시가 판정이 되지 않는다"
  rm -rf "$T"
}

case_non_utf8_recritic_is_dead_adjudicator() {
  # Review Focus 5 — traceback(exit 1)이 아니라 주 입력 실패다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"; prep "$T"
  printf '```docreview-recritic\nverdicts: []\n```\n# \xff\xfe\n' > "$T/reply.txt"
  local out rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "비-UTF-8 응답 — rc 0 (traceback 아님)"
  assert_grep "$out" '^reason: angle-absent$' "비-UTF-8 응답은 판정자 사망이다"
  printf '{"f1": \xff}' > "$T/map.json"
  printf '```docreview-recritic\nverdicts: []\n```\n' > "$T/reply.txt"
  rc=0; out=$(synth "$T" --emit-verdict 2>/dev/null) || rc=$?
  assert_eq   "$rc" "0" "비-UTF-8 매핑 — rc 0"
  assert_grep "$out" '^reason: angle-absent$' "비-UTF-8 매핑은 판정자 사망이다"
  rm -rf "$T"
}

case_flag_hygiene() {
  local T; T=$(mktemp -d); printf '[]\n' > "$T/findings.yaml"; prep "$T"; reply "$T/reply.txt" 'verdicts: []'
  local rc
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "$T/reply.txt" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic 에는 --recritic-map 이 필요하다"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic-map "$T/map.json" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic-map 만 주면 exit 2"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "" --recritic-map "$T/map.json" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --recritic 은 exit 2"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic-diff "$T/x.diff" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic-diff 는 --recritic 없이 의미가 없다"
  # Minor 7 (fix round 1)
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "$T/reply.txt" --recritic-map "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --recritic-map 은 exit 2"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "$T/reply.txt" --recritic-map "$T/map.json" --recritic-diff "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --recritic-diff 는 exit 2"
  rm -rf "$T"
}

case_adjudicator_name_matches_the_canonical_agent() {
  # R-M 의 계약을 이 층에서 — 승격 저자 이름이 재비판자 agent 의 frontmatter name: 과
  # 같고 수행자 문법 안이어야 한다. 다르면 승격분의 저자와 오케스트레이터가 찍는 수행자
  # 토큰이 갈린다.
  local name const
  name="$(sed -n 's/^name:[[:space:]]*//p' "$REPO_ROOT/shared/docreview/agents/doc-recritic.md" | head -1)"
  const="$(python3 -c "import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import recritic_bridge as b; print(b.ADJUDICATOR)")"
  assert_eq "$const" "$name" "ADJUDICATOR 가 재비판자 정본의 name: 과 같다"
}

case_adversarial_flag_is_gone() {
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml"
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local rc=0
  python3 "$SYNTH" --findings "$T/findings.yaml" --adversarial "$T/adv.yaml" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--adversarial 은 모르는 인자다(exit 2) — 판정자는 재비판 경로 하나다"
  # 양의 짝 — 같은 입력을 재비판 경로로 주면 선다.
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: confirm'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: defect$' "재비판 경로는 그대로 선다"
  rm -rf "$T"
}

case_downgrade_is_not_a_verb() {
  # 재비판자에게 하향은 없다. `downgrade` 는 모르는 verdict — confirm 으로 강제되고
  # 그 강제는 판정을 바꾼 것으로 공시된다. severity 는 그대로다.
  local T; T=$(mktemp -d)
  one_finding "$T/findings.yaml" security-reviewer app.py 10 CRITICAL
  prep "$T"
  reply "$T/reply.txt" 'verdicts:
  - f: f1
    verdict: downgrade
    to: SUGGESTION'
  local out; out=$(synth "$T" --emit-verdict)
  assert_grep "$out" '^\| CRITICAL \| app\.py:10 \|' "CRITICAL 이 내려가지 않는다"
  assert_grep "$out" "강제\(게이트 변경\): verdict 'downgrade'" "모르는 verdict 는 게이트 강제로 공시된다"
  rm -rf "$T"
}

case_prepare_strips_source_and_keeps_severity
case_prepare_empty_states_the_empty_slot
case_prepare_unreadable_findings_is_fail4_without_outputs
case_identity_parity_with_weird_fields
case_reject_needs_evidence
case_raise_goes_up_only
case_unknown_verdict_value_is_coerced_to_confirm
case_misspelled_f_is_held_not_matched
case_duplicate_verdicts_for_one_f_are_held
case_colliding_ids_with_split_verdicts_are_not_resolved
case_colliding_ids_with_partial_verdicts_are_not_resolved
case_colliding_ids_with_matching_verdicts_are_resolved
case_colliding_ids_with_raise_that_differs_per_severity_are_not_resolved
case_colliding_ids_with_raise_ignored_for_one_severity_are_not_resolved
case_colliding_ids_with_raise_to_different_targets_are_not_resolved
case_raise_cannot_lower_when_map_is_stale
case_raise_to_same_severity_is_noop_not_degrade
case_missing_verdict_is_unadjudicated
case_same_as_keeps_both
case_added_becomes_promoted_by_doc_recritic
case_added_file_derivation_is_single_file_only
case_recritic_zero_is_stated
case_recritic_zero_not_claimed_when_added_is_suppressed_or_broken
case_recritic_zero_not_claimed_when_added_or_verdicts_are_malformed
case_added_severity_case_folds
case_raise_to_case_folds
case_added_falls_back_to_disposition_when_severity_missing
case_dead_recritic_is_not_clean
case_malformed_map_entry_is_dead_adjudicator
case_truncated_block_is_dead_adjudicator
case_last_block_wins
case_non_utf8_recritic_is_dead_adjudicator
case_flag_hygiene
case_adjudicator_name_matches_the_canonical_agent
case_adversarial_flag_is_gone
case_downgrade_is_not_a_verb
finish
