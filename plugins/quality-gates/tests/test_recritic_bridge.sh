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
  # 대조 — 옛 판정자 경로에서는 이 줄이 없다(재비판자가 돈 사실이 아니다)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  out=$(python3 "$SYNTH" --findings "$T/findings.yaml" --adversarial "$T/adv.yaml")
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
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local rc
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --adversarial "$T/adv.yaml" --recritic "$T/reply.txt" --recritic-map "$T/map.json" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--adversarial 과 --recritic 은 함께 줄 수 없다 (exit 2)"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "$T/reply.txt" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic 에는 --recritic-map 이 필요하다"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic-map "$T/map.json" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic-map 만 주면 exit 2"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic "" --recritic-map "$T/map.json" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --recritic 은 exit 2"
  rc=0; python3 "$SYNTH" --findings "$T/findings.yaml" --recritic-diff "$T/x.diff" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--recritic-diff 는 --recritic 없이 의미가 없다"
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
case_missing_verdict_is_unadjudicated
case_same_as_keeps_both
case_added_becomes_promoted_by_doc_recritic
case_added_file_derivation_is_single_file_only
case_recritic_zero_is_stated
case_recritic_zero_not_claimed_when_added_is_suppressed_or_broken
case_dead_recritic_is_not_clean
case_truncated_block_is_dead_adjudicator
case_last_block_wins
case_non_utf8_recritic_is_dead_adjudicator
case_flag_hygiene
case_adjudicator_name_matches_the_canonical_agent
finish
