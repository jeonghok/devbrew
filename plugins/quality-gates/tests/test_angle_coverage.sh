#!/usr/bin/env bash
# test_angle_coverage.sh — AC10 · AC10a · AC11 · AC12 (설계 §6.3.1 · §6.3.2).
#
# 이 락의 앵커는 SKILL.md 의 명단 리터럴이 아니다 — 그것은 **피검자가 쥔 앵커**라
# 모델이 산문을 고치면 락이 따라 움직인다. 앵커는 합성기가 쓰는 모듈의 ∀ 관계다:
# 각도 셋 전부가 상태를 갖지 않으면 exit 4 이고, 그 「셋」은 이 락이 열거하지 않고
# `angles.py` 에서 **도출**한다.
#
# **이 락이 재지 «않는» 것(설계 §15-4)** — 「각도가 상태를 가졌는가」는 재지만
# 「그 상태가 참인가」는 못 잰다. 모델이 세 각도를 전부 `folded_into:` 로 주장하면
# 이 락은 GREEN 이다. 형식적 완전성의 락이지 진실성의 락이 아니다.
#
# **오늘 배선이 안 된 것** — `--angles` 는 기본 off 다(계획 R-E). 오케스트레이터가
# 그것을 «항상» 싣게 만드는 것은 PR4 의 빚이고, 이 락은 그 빚을 재지 못한다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
A="$PLUGIN_ROOT/scripts/angles.py"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
export PYTHONDONTWRITEBYTECODE=1

TMP="$(mktemp -d -t angles-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# 열거를 **모듈에게 물어** 가져온다. 여기에 리터럴을 복사하면 두 자리가 어긋날 때
# 락이 자기 사본만 보고 GREEN 을 낸다.
ANGLES="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.ANGLES))")"
BLOCKING="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.BLOCKING_ANGLES))")"
REASONS="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print('\n'.join(angles.ABSENT_REASONS))")"

# 도출이 실패하면(모듈 부재·문법 오류) 아래 전부가 «빈 코퍼스 위의 통과»가 된다.
# 침묵하지 않고 여기서 먼저 밝힌다 — vacuous 락은 통과가 곧 증거가 아니다.
if [ -z "$ANGLES" ] || [ -z "$BLOCKING" ] || [ -z "$REASONS" ]; then
  no "angles.py 에서 열거를 도출하지 못했다 — 아래 단언은 아무것도 재지 않는다"
  # `finish` 는 «종료하지 않는다» — 값을 반환할 뿐이다(`shared/tests/assert.sh:111-114`).
  # 뒤에 `exit` 가 없으면 스크립트가 그대로 계속 돌아 빈 코퍼스 위에서 단언을 쌓는다.
  # 인자 없는 `exit` 는 직전 명령(`finish`)의 상태로 나간다.
  finish; exit
fi

# write_angles <파일> <"각도: 상태"...>  — 생략된 각도는 안 쓴다(총 함수 검사용)
write_angles() {
  local f="$1"; shift
  : > "$f"
  local kv
  for kv in "$@"; do printf '%s\n' "$kv" >> "$f"; done
}

# mk_inputs <디렉토리> — 판정 0 · finding 0 인 «깨끗한» 입력 한 벌.
# 이 벌을 기준으로 각도만 바꿔 가며 AC11·AC12 를 가른다: 각도 말고는 clean 을
# 막을 것이 아무것도 없어야 「각도가 막았다」가 입증된다.
mk_inputs() {
  printf 'verdicts: []\n' > "$1/adv.yaml"
  printf '[]\n' > "$1/f.yaml"
}

case_synth_angles_off_equals_on_minus_block() {
  # `--angles` 를 안 주면 `angles:` 블록이 없고, 나머지 stdout 은 블록을 뺀 on 과
  # 같아야 한다(계획 R-E). rc 를 먼저 재는 이유 — 죽은 경로의 빈 출력은 어떤
  # 접두 검사도 트리비얼하게 통과시킨다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  local off on off_rc=0 on_rc=0
  off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict) || off_rc=$?
  on=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f") || on_rc=$?
  assert_eq "$off_rc" "0" "각도 없는 경로가 정상 종료한다"
  assert_eq "$on_rc"  "0" "각도 있는 경로가 정상 종료한다"
  assert_not_grep "$off" '^angles:$' "--angles 를 안 주면 angles: 블록이 없다"
  assert_grep     "$on"  '^angles:$' "--angles 가 angles: 블록을 켠다"
  assert_grep     "$on"  '^verdict: clean$' "셋 다 filled 면 clean 이다"
  # Ruling P2 — 이름이 주장하는 것을 실제로 잰다: `on` 에서 `angles:` 블록(헤더
  # 1줄 + 각도 개수만큼의 줄, `ANGLES` 에서 도출해 하드코딩하지 않는다)을 빼면
  # `off` 와 바이트 단위로 같아야 한다(R-J 의 불변식). 블록은 `on` 의 render()
  # 본문 «뒤», `verdict:` 줄 «앞»에 온다 — 맨 앞이 아니라 그 위치에서 정확히
  # `angles:` 줄과 그 다음 각도-수만큼의 줄만 잘라낸다.
  local angle_lines; angle_lines=$(printf '%s\n' "$ANGLES" | wc -l | tr -d ' ')
  local on_tail; on_tail=$(printf '%s\n' "$on" | awk -v n="$angle_lines" '
    /^angles:$/ { skip = n; next }
    skip > 0 { skip--; next }
    { print }
  ')
  assert_eq "$on_tail" "$off" \
    "off 는 on 에서 angles: 블록(헤더 1줄 + 각도 ${angle_lines}줄)을 뺀 것과 바이트 동일하다"
  # 위 동치는 블록을 «어디서든» 잘라내므로 위치를 재지 않는다 — 블록이 `verdict:`
  # 뒤로 가도(또는 맨 앞으로 가도) 그대로 GREEN 이다(변이로 실측). 위치(R-J: 본문
  # 뒤 · `verdict:` 바로 앞)를 따로 핀한다: 블록 다음 줄이 `verdict: ` 여야 한다.
  local after_block; after_block=$(printf '%s\n' "$on" | awk -v n="$angle_lines" '
    /^angles:$/ { skip = n; seen = 1; next }
    skip > 0 { skip--; next }
    seen == 1 { print; exit }
  ')
  assert_grep "$after_block" '^verdict: ' "angles: 블록 바로 다음 줄이 verdict: 다 (R-J 의 위치)"
  rm -rf "$T"
}

case_synth_blocking_absent_is_not_certified() {
  # ★ AC11 의 **양의 짝**. 각도 coverage 락의 존재 이유가 이 케이스다 —
  # 「상태가 있는가」만 재는 락은 통째로 지워도 통과한다(음의 락). 부재가
  # 실제로 `clean` 을 «막는지» 를 여기서 관측한다.
  local T a b f out
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    T=$(mktemp -d); mk_inputs "$T"; f="$T/angles.txt"; : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
            --emit-verdict --angles "$f")
    assert_grep     "$out" '^verdict: not-certified$' "'$a' 가 absent 면 미판정 (AC11)"
    assert_grep     "$out" '^reason: angle-absent$'   "'$a' 의 사유가 angle-absent 다"
    assert_not_grep "$out" '^verdict: clean$'          "'$a' 가 absent 인데 clean 이 아니다"
    assert_grep     "$out" "^  $a: absent\$"           "그 부재가 산출물에 드러난다"
    rm -rf "$T"
  done <<< "$BLOCKING"
}

case_synth_different_premise_absent_stays_clean() {
  # AC12 — 모델 다양성 손실은 공시하고 막지 않는다. 위 케이스와 이 케이스가
  # **짝**이다: 하나만 두면 「전부 막는다」와 「전부 안 막는다」를 구별 못 한다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
                     --emit-verdict --angles "$f")
  assert_grep     "$out" '^verdict: clean$'               "다른 전제의 부재는 막지 않는다 (AC12)"
  assert_grep     "$out" '^  different-premise: absent$'  "그래도 공시된다"
  assert_not_grep "$out" '^reason: angle-absent$'         "사유가 서지 않는다"
  rm -rf "$T"
}

case_synth_self_adjudication_is_atomic_failure() {
  # AC10a 를 합성기 층에서. **그리고 fail4 의 원자성** — 실패 경로에서 stdout 이
  # 비어 있어야 한다. 비어 있지 않으면 rc 를 안 보는 줄-지향 소비자가 완전해
  # 보이는 보고서를 성공으로 읽는다(PR2 Ruling T5-b 가 산 자리).
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- {agent: security-reviewer, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  assert_eq "$rc" "4" "finding 을 낸 리뷰어에게 판정 각도를 접으면 exit 4 (AC10a)"
  assert_eq "$out" ""  "실패 경로의 stdout 이 비어 있다 (fail4 는 원자적이다)"
  # 원인을 핀한다 — rc 4 + 빈 stdout 은 어느 fail4 든 만든다(수행자 문법 오류도).
  assert_contains "$(cat "$T/err")" "AC10a" "exit 4 의 원인이 AC10a 다 (다른 fail4 가 아니다)"
  rm -rf "$T"
}

case_synth_folding_into_a_silent_reviewer_is_ok() {
  # 위 케이스의 양의 짝(합성기 층). 같은 모양인데 접힌 수행자가 이 실행에서 finding 을
  # «안 냈으면» 정상이다. 이것이 없으면 「folded_into 를 전부 막는다」나 「저자를 각도
  # 파일에서 뽑는다」(계획 R-H 가 기각한 대안)가 위 케이스와 구별되지 않는다.
  local T; T=$(mktemp -d)
  printf 'verdicts:\n  - {finding_id: security-reviewer-a.py-1, verdict: confirm}\n' > "$T/adv.yaml"
  printf -- '- {agent: security-reviewer, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>/dev/null) || rc=$?
  assert_eq   "$rc"  "0"                      "finding 을 안 낸 리뷰어에게 접는 것은 합성기에서도 정상이다"
  assert_grep "$out" '^  adjudication: folded_into:scout$' "접힌 상태가 그대로 공시된다"
  assert_grep "$out" '^verdict: '             "판정이 선다"
  rm -rf "$T"
}

case_synth_suppressed_finding_still_counts_as_authored() {
  # 계획 R-H — 억제된(suppressed) finding 도 「낸 것」이다. 억제분을 빼면 임계값 아래
  # finding 만 낸 리뷰어가 자기 판정을 할 수 있다. 저자를 `kept` 에서 뽑는 변이가
  # 이 케이스 없이 스위트 전체를 GREEN 으로 남겼다(변이 표 16행).
  local T; T=$(mktemp -d)
  printf 'verdicts:\n  - {finding_id: scout-a.py-1, verdict: confirm}\n' > "$T/adv.yaml"
  printf -- '- {agent: scout, file: a.py, line: 1, severity: SUGGESTION, confidence: 3, summary: s, proposed_fix: f}\n' > "$T/f.yaml"
  # 전제 확인 — 이 픽스처의 유일한 finding 이 실제로 «억제» 경로를 탄다. 안 타면
  # 아래 exit 4 는 억제와 무관한 이유로 선다.
  local off; off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$off" 'No high-confidence findings\. 1 low-confidence' "전제: 픽스처의 finding 은 억제된다"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  assert_eq "$rc" "4" "억제된 finding 만 낸 리뷰어에게 판정 각도를 접어도 exit 4 (R-H)"
  assert_eq "$out" "" "실패 경로의 stdout 이 비어 있다"
  assert_contains "$(cat "$T/err")" "AC10a" "원인이 AC10a 다"
  rm -rf "$T"
}

# mk_rejected <디렉토리> <저자> — <저자> 의 유일한 finding 을 adversarial 이 기각한 입력.
mk_rejected() {
  printf 'verdicts:\n  - {finding_id: %s-a.py-1, verdict: reject}\n' "$2" > "$1/adv.yaml"
  printf -- '- {agent: %s, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: rejected-one, proposed_fix: f}\n' "$2" > "$1/f.yaml"
}

case_synth_rejected_finding_still_counts_as_authored() {
  # AC10a 는 «생존»이 아니라 «저자»를 묻는다 — 기각된 finding 도 「낸 것」이다.
  # 판정이 X 에게 접혔는데 X 의 유일한 finding 이 기각됐다면 X 가 자기 finding 을
  # 판정한 것이다(Law 2). 판정 적용이 기각분을 버린 «뒤» 에 저자를 뽑으면 rc 0 +
  # verdict: clean 으로 샌다.
  local T; T=$(mktemp -d); mk_rejected "$T" scout
  # 전제 확인 — 이 픽스처의 finding 은 실제로 기각된다(표에 안 실린다).
  local off; off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_not_grep "$off" 'rejected-one' "전제: 픽스처의 finding 은 기각돼 표에 없다"
  assert_grep     "$off" '^verdict: clean$' "전제: --angles 없이는 clean 이다"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  assert_eq "$rc" "4" "기각된 finding 만 낸 리뷰어에게 판정 각도를 접어도 exit 4 (AC10a)"
  assert_eq "$out" "" "실패 경로의 stdout 이 비어 있다"
  assert_contains "$(cat "$T/err")" "AC10a" "원인이 AC10a 다"
  rm -rf "$T"
}

case_synth_reviewer_sources_do_not_displace_agent() {
  # 판정 적용 전 입력의 `sources` 는 리뷰어가 준 비신뢰 값이다. 그것이 `agent` 를
  # 대신하면 기각된 finding 에 `sources: [다른-이름]` 만 적어도 AC10a 가 조용해진다.
  # 리스트 아닌 참 값(문법 안 스칼라 `someone-else`)도 같은 방식으로 `agent` 를
  # 가릴 수 있다 — 둘 다 잰다. 문법 «밖» 값(`{a: 1}`)은 이제 신원 계약이 먼저
  # 잡는다 — 그 모양은 `case_synth_author_identity_is_grammar_checked` 가 잰다.
  local T srcs off out rc
  for srcs in '[someone-else]' 'someone-else'; do
    T=$(mktemp -d); mk_rejected "$T" scout
    printf -- '- {agent: scout, sources: %s, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: rejected-one, proposed_fix: f}\n' "$srcs" > "$T/f.yaml"
    off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
    assert_not_grep "$off" 'rejected-one' "전제: sources=$srcs 인 finding 도 기각돼 표에 없다"
    write_angles "$T/angles.txt" "security: filled" "adjudication: folded_into:scout" \
                                 "different-premise: filled"
    rc=0; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
                  --emit-verdict --angles "$T/angles.txt" 2>"$T/err") || rc=$?
    assert_eq "$rc" "4" "sources=$srcs 가 agent 를 가리지 않는다 — 기각된 finding 의 저자에게 접으면 exit 4"
    assert_eq "$out" "" "실패 경로의 stdout 이 비어 있다 (sources=$srcs)"
    assert_contains "$(cat "$T/err")" "AC10a" "원인이 AC10a 다 (sources=$srcs)"
    rm -rf "$T"
  done
}

case_synth_promoted_finding_counts_as_authored() {
  # 승격된 finding(adversarial 의 `new_findings:`, 저자 `adversarial`)도 「낸 것」이다.
  # 판정 적용 전 입력(`raw`)에는 없고 dedup 뒤 목록에만 있다 — 저자를 `raw` 에서만
  # 뽑는 변이가 이 케이스 없이 스위트를 GREEN 으로 남겼다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\nnew_findings:\n  - {file: b.py, line: 2, severity: IMPORTANT, summary: promoted-one}\n' > "$T/adv.yaml"
  printf '[]\n' > "$T/f.yaml"
  local off; off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$off" 'promoted-one' "전제: 픽스처의 new_findings 가 승격돼 표에 실린다"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:adversarial" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  assert_eq "$rc" "4" "승격된 finding 의 저자에게 판정 각도를 접으면 exit 4 (AC10a)"
  assert_eq "$out" "" "실패 경로의 stdout 이 비어 있다"
  assert_contains "$(cat "$T/err")" "AC10a" "원인이 AC10a 다"
  # 억제된 승격분 — `raw` 에 없고 억제 뒤 `kept` 에도 없다. dedup 뒤 목록만 이 저자를
  # 본다. 저자를 `kept + raw` 에서 뽑는 변이(억제분 제외)를 이것만 가른다.
  printf 'verdicts: []\nnew_findings:\n  - {file: b.py, line: 2, severity: SUGGESTION, confidence: 3, summary: promoted-low}\n' > "$T/adv.yaml"
  off=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$off" 'No high-confidence findings\. 1 low-confidence' "전제: 승격분이 억제된다"
  rc=0; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  assert_eq "$rc" "4" "억제된 승격분의 저자에게 접어도 exit 4 (R-H)"
  assert_eq "$out" "" "실패 경로의 stdout 이 비어 있다 (억제된 승격분)"
  assert_contains "$(cat "$T/err")" "AC10a" "원인이 AC10a 다 (억제된 승격분)"
  rm -rf "$T"
}

case_synth_rejected_finding_of_another_reviewer_is_ok() {
  # 위 케이스의 양의 짝 — 기각된 finding 의 저자가 접힌 수행자가 아니면 정상이다.
  # 이것이 없으면 「기각이 있으면 전부 막는다」와 구별되지 않는다.
  local T; T=$(mktemp -d); mk_rejected "$T" security-reviewer
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
          --emit-verdict --angles "$f" 2>/dev/null) || rc=$?
  assert_eq   "$rc"  "0"               "다른 리뷰어의 기각된 finding 은 접기를 막지 않는다"
  assert_grep "$out" '^verdict: clean$' "판정이 clean 으로 선다"
  rm -rf "$T"
}

case_synth_angles_flag_hygiene() {
  # PR2 의 I1 이 세 플래그에 건 대칭을 네 번째 플래그에도 건다. 안 걸면 값을
  # 구하고도 `--emit-verdict` 를 빼먹은 호출자가 rc=0 + 완전해 보이는 보고서를
  # 받고, 각도 축이 그 실행에서 빠졌다는 사실이 어느 채널에도 안 남는다.
  local T; T=$(mktemp -d); mk_inputs "$T"
  local f="$T/angles.txt"
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  local rc=0
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
    --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--angles 는 --emit-verdict 없이는 usage 오류(exit 2)"
  rc=0
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" \
    --emit-verdict --angles "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 --angles 는 usage 오류(exit 2)"
  rm -rf "$T"
}

case_synth_primary_source_death_is_angle_absent() {
  # C3 의 **관측 가능한 결과**. 주 판정자(여기서는 `--findings` 가 가리키는 파일)가
  # 통째로 죽으면 그것은 「항목을 잃었다」가 아니라 「아무도 안 봤다」다 — PR2 는
  # 이 실행을 `findings-lost` 로 보고했다. `--angles` 없이도 서야 한다: 이 사유의
  # 산출자는 각도 파일이 아니라 원장이다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local out; out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" \
                     --findings "$T/does-not-exist.yaml" --emit-verdict)
  assert_grep     "$out" '^verdict: not-certified$' "주 입력이 죽으면 미판정"
  assert_grep     "$out" '^reason: angle-absent$'   "사유가 angle-absent 다 (findings-lost 가 아니다)"
  assert_not_grep "$out" '^reason: findings-lost$'  "항목 소실로 오보고하지 않는다"
  rm -rf "$T"
}

case_synth_missing_adjudicator_doc_is_angle_absent() {
  # 부채 A (PR3 최종 리뷰) — 판정자 문서 경로를 줬는데 파일이 없다. 전에는
  # `load_yaml_doc` 이 None 을 돌려 「판정자를 안 썼다」와 같아졌고, finding 이
  # 0 이면 그대로 `clean` 이었다. 이제 주 입력 실패다(§6.4.3 — angle-absent).
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/f.yaml"
  local out rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/gone.yaml" --findings "$T/f.yaml" --emit-verdict) || rc=$?
  assert_eq "$rc" "0" "판정자 문서 부재는 호출 오류가 아니다 (rc 0)"
  assert_grep     "$out" '^verdict: not-certified$' "판정자 문서가 없으면 clean 이 아니다"
  assert_grep     "$out" '^reason: angle-absent$'   "사유는 angle-absent 다"
  assert_not_grep "$out" '^verdict: clean$'         "clean 으로 렌더되지 않는다"
  rm -rf "$T"
}

case_synth_unusable_adjudicator_doc_is_angle_absent() {
  # 부채 A 의 형제들 — 빈 파일 · YAML 파손 · 스칼라 · 비-UTF-8. 넷 다 「판정자가
  # 아무것도 남기지 않았다」이고, 넷 다 traceback(exit 1)이 아니라 rc 0 + 미판정이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/f.yaml"
  : > "$T/empty.yaml"
  printf 'verdicts: [\n' > "$T/broken.yaml"
  printf '5\n' > "$T/scalar.yaml"
  printf 'verdicts: []\n# \xff\xfe\n' > "$T/nonutf8.yaml"
  local k out rc
  for k in empty broken scalar nonutf8; do
    rc=0
    out=$(python3 "$SYNTH" --adversarial "$T/$k.yaml" --findings "$T/f.yaml" --emit-verdict 2>/dev/null) || rc=$?
    assert_eq "$rc" "0" "판정자 문서 '$k' — rc 0 (traceback 이 아니다)"
    assert_grep "$out" '^reason: angle-absent$' "판정자 문서 '$k' — angle-absent"
  done
  rm -rf "$T"
}

case_synth_dead_adjudicator_with_findings_is_not_findings_lost() {
  # 계획 R-K — 판정자 사망은 한 사건이다. finding 이 있어도 항목마다 「판정자 부재」
  # 보류를 쌓지 않는다. 전에는 그 보류가 `findings-lost` 를 켜서 열거 순서상 먼저
  # 나갔다. finding 이 살아 있으므로 판정은 defect 이고, 사유 목록에는 angle-absent
  # 만 있어야 한다.
  local T; T=$(mktemp -d)
  cat > "$T/f.yaml" <<'YAML'
- agent: scout
  file: a.py
  line: 3
  severity: IMPORTANT
  confidence: 8
  summary: "x"
YAML
  local out
  out=$(python3 "$SYNTH" --adversarial "$T/gone.yaml" --findings "$T/f.yaml" --emit-verdict)
  assert_grep     "$out" '^verdict: defect$'              "finding 은 살아남는다 (사람 쪽 fail-open)"
  assert_grep     "$out" '^reasons: \[angle-absent\]$'    "사유 목록은 angle-absent 하나다"
  assert_not_grep "$out" 'findings-lost'                  "항목 소실로 세지 않는다 (R-K)"
  rm -rf "$T"
}

case_synth_adjudicator_given_but_absent_differs_from_not_given() {
  # 대조 — 판정자 경로를 «안 준» 실행은 사망이 아니다(오늘 동작 그대로). finding 0
  # 이면 clean 이다. 이 짝이 없으면 「경로 유무와 무관하게 전부 미판정」으로 구현해도
  # 위 케이스들이 통과한다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/f.yaml"
  local out
  out=$(python3 "$SYNTH" --findings "$T/f.yaml" --emit-verdict)
  assert_grep "$out" '^verdict: clean$' "판정자 경로를 안 주면 사망이 아니다 (finding 0 → clean)"
  rm -rf "$T"
}

case_synth_effective_angles_show_the_dead_source() {
  # 계획 R-L — 선언은 filled 인데 판정자가 죽었다. 꼬리는 자기모순이면 안 된다:
  # 실효 상태 `absent(source-failed)` 가 angles: 블록에 서고, 그 아래 사유가
  # angle-absent 다. finding 파일이 죽으면 보안 각도가 같은 표시를 받는다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/f.yaml"
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local f="$T/angles.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  out=$(python3 "$SYNTH" --adversarial "$T/gone.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f")
  assert_grep     "$out" '^  adjudication: absent\(source-failed\)$' "판정자 사망이 판정 각도의 실효 상태로 보인다"
  assert_grep     "$out" '^  security: filled$'                      "살아 있는 축은 선언 그대로다"
  assert_not_grep "$out" '^  adjudication: filled$'                  "죽은 축을 filled 로 싣지 않는다 (자기모순 없음)"
  assert_grep     "$out" '^reason: angle-absent$'                    "사유와 각도 블록이 같은 사실을 말한다 (판정자 사망)"
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/gone.yaml" --emit-verdict --angles "$f")
  assert_grep     "$out" '^  security: absent\(source-failed\)$'     "finding 파일 사망은 보안 각도의 실효 상태다"
  assert_grep     "$out" '^  adjudication: filled$'                  "판정자는 살아 있다"
  assert_grep     "$out" '^reason: angle-absent$'                    "사유와 각도 블록이 같은 사실을 말한다"
  rm -rf "$T"
}

case_synth_dead_adjudicator_does_not_launder_self_adjudication() {
  # 계획 R-L 의 경계 — AC10a 는 «선언»에 건다. 판정자가 죽어 실효 상태가
  # `absent(source-failed)` 로 덮여도, 선언이 자기 판정(`folded_into:<그 실행의 저자>`)
  # 이면 거부해야 한다. 실효 상태에 걸면 판정자 사망이 Law 2 위반 선언을 «세탁»한다
  # (계획 모의 실행 변이 6b 가 rc 4 → rc 0 · `verdict: defect` 로 측정한 구멍).
  local T; T=$(mktemp -d)
  printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "x"\n' > "$T/f.yaml"
  local f="$T/angles.txt" out rc=0 err
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" "different-premise: filled"
  out=$(python3 "$SYNTH" --adversarial "$T/gone.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  err="$(cat "$T/err")"
  assert_eq       "$rc"  "4"                   "판정자가 죽어도 자기 판정 선언은 exit 4"
  assert_eq       "$out" ""                    "실패는 원자적이다 (빈 stdout)"
  assert_contains "$err" "자기 finding 자기 판정" "원인이 자기 판정이다 (실효 상태로 세탁되지 않는다)"
  rm -rf "$T"
}

case_dead_sources_only_for_blocking_angles() {
  # `with_dead_sources` 는 막는 각도만 받는다 — 다른 전제 각도의 사망은 차단 축이 아니다
  # (AC12). 합성기는 그 이름을 넘기지 않으므로 이 가드는 모듈 API 수준에서만 잴 수 있다
  # (모의 실행 변이 8 — 합성기 경로로는 GREEN 이었다).
  local rc=0
  python3 -c "
import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import angles
angles.with_dead_sources({'security': 'filled', 'adjudication': 'filled', 'different-premise': 'filled'}, ['different-premise'])
" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "막는 각도가 아닌 이름을 사망으로 얹으면 exit 4"
}

case_orchestrator_may_declare_source_failed() {
  # 계획 R-L — `absent(source-failed)` 는 문법 «안»의 값이다. 오케스트레이터도
  # 「디스패치했는데 아무것도 안 돌아왔다」를 그 값으로 적을 수 있다.
  local f="$TMP/sf.txt" out rc=0
  write_angles "$f" "security: filled" "adjudication: absent(source-failed)" "different-premise: filled"
  out="$(python3 "$A" --angles "$f")" || rc=$?
  assert_eq   "$rc" "0" "absent(source-failed) 는 문법 안이다"
  assert_grep "$out" '^angle_absent: true$' "판정 각도의 source-failed 는 막는다"
}

case_synth_author_identity_is_grammar_checked() {
  # 부채 B (PR3 최종 리뷰) — 수행자 쪽만 문법(`_PERFORMER`)을 검사하고 저자 쪽은 안
  # 했다. finding `agent: Security-Reviewer` 에 판정 각도를
  # `folded_into:security-reviewer` 로 접으면 두 문자열이 달라 AC10a 가 조용히
  # 통과했다(대문자 한 글자로 자기 판정). 이제 저자 이름이 문법 밖이면 판정 자체를
  # 거부한다(R-M — 정규화하지 않는다: 접는 것은 추측이다).
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  local f="$T/angles.txt" name out err rc
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" "different-premise: filled"
  for name in 'Security-Reviewer' 'quality-gates:security-reviewer' 'security_reviewer' 'security reviewer'; do
    printf -- '- agent: "%s"\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "x"\n' "$name" > "$T/f.yaml"
    rc=0
    out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
    err="$(cat "$T/err")"
    assert_eq       "$rc"  "4"      "저자 '$name' 는 문법 밖이라 exit 4"
    assert_eq       "$out" ""       "저자 '$name' — 실패는 원자적이다 (빈 stdout)"
    assert_contains "$err" "AC10a"  "저자 '$name' — 원인이 AC10a 신원 계약이다"
  done
  # 모의 실행 A1 — sources 가 리스트 아닌 참 값(모양 {a: 1})이면 str() 이 문법 밖
  # 문자열을 만든다. agent 자체는 문법 안이어도 신원 계약이 여전히 막는다.
  printf -- '- agent: security-reviewer\n  sources: {a: 1}\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "x"\n' > "$T/f.yaml"
  rc=0
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f" 2>"$T/err") || rc=$?
  err="$(cat "$T/err")"
  assert_eq       "$rc"  "4"          "sources={a: 1} 도 문법 밖 저자를 만든다"
  assert_eq       "$out" ""           "실패는 원자적이다 (sources={a: 1})"
  assert_contains "$err" "AC10a"      "원인이 AC10a 다 (sources={a: 1})"
  assert_contains "$err" "문법 밖 저자" "메시지가 문법 밖 저자를 댄다 (sources={a: 1})"
  rm -rf "$T"
}

case_synth_finding_without_agent_is_rejected_under_angles() {
  # R-M — `agent:` 를 뺀 finding 은 저자가 없다. 건너뛰면 리뷰어가 `agent:` 를 빼는
  # 것만으로 자기 판정이 된다(PR3 가 닫은 sources 우회와 같은 모양).
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "x"\n' > "$T/f.yaml"
  local f="$T/angles.txt" rc=0 err
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f" >/dev/null 2>"$T/err" || rc=$?
  err="$(cat "$T/err")"
  assert_eq       "$rc"  "4"     "agent 없는 finding 은 --angles 아래서 exit 4"
  assert_contains "$err" "AC10a" "원인이 AC10a 신원 계약이다"
  # 대조 — --angles 가 없으면 신원 계약은 서지 않는다(오늘 동작 그대로)
  rc=0
  python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "--angles 없이는 agent 없는 finding 도 통과한다 (계약은 각도 축의 것)"
  rm -rf "$T"
}

case_synth_well_formed_authors_pass_identity() {
  # 양성 짝 — 문법 안의 저자만 있으면 신원 검사는 조용하다. 이 짝이 없으면
  # 「--angles 면 무조건 exit 4」로 구현해도 위 두 케이스가 통과한다.
  local T; T=$(mktemp -d)
  printf 'verdicts: []\n' > "$T/adv.yaml"
  printf -- '- agent: security-reviewer\n  file: a.py\n  line: 1\n  severity: IMPORTANT\n  confidence: 8\n  summary: "x"\n  sources: [security-reviewer, codex]\n' > "$T/f.yaml"
  local f="$T/angles.txt" rc=0 out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  out=$(python3 "$SYNTH" --adversarial "$T/adv.yaml" --findings "$T/f.yaml" --emit-verdict --angles "$f") || rc=$?
  assert_eq   "$rc" "0" "문법 안의 저자(agent · sources)는 통과한다"
  assert_grep "$out" '^verdict: defect$' "판정이 선다"
  rm -rf "$T"
}

case_reviewer_persona_agent_literal_is_its_name() {
  # 계약의 리뷰어 쪽 — 페르소나가 출력 형식에 박는 `agent:` 리터럴이 그 agent 의
  # frontmatter `name:` 과 같고 문법 안이어야 한다. 다르면 오케스트레이터가 찍는
  # 수행자 토큰(=name)과 finding 의 저자가 갈려 AC10a 가 조용해진다.
  local p="$PLUGIN_ROOT/agents/security-reviewer.md" name lit
  name="$(sed -n 's/^name:[[:space:]]*//p' "$p" | head -1)"
  lit="$(sed -n 's/^- agent:[[:space:]]*//p' "$p" | head -1)"
  assert_eq "$lit" "$name" "security-reviewer 의 출력 형식 agent: 가 frontmatter name: 과 같다"
  if printf '%s\n' "$lit" | grep -qE '^[a-z0-9-]+$'; then
    ok "security-reviewer 의 agent: 가 수행자 문법 안이다"
  else
    no "security-reviewer 의 agent: 가 수행자 문법 밖이다: '$lit'"
  fi
}

case_all_three_filled_is_ok() {
  local f="$TMP/ok.txt" out rc=0
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: filled"
  out="$(python3 "$A" --angles "$f")" || rc=$?
  assert_eq "$rc" "0" "세 각도가 전부 상태를 가지면 exit 0"
  assert_grep "$out" '^angles:$'                     "angles: 블록이 나온다"
  assert_grep "$out" '^  security: filled$'          "보안 각도 한 줄"
  assert_grep "$out" '^  adjudication: filled$'      "판정 각도 한 줄"
  assert_grep "$out" '^  different-premise: filled$' "다른 전제 각도 한 줄"
  assert_grep "$out" '^angle_absent: false$'         "막지 않는다"
}

case_every_angle_is_required() {
  # AC10 — **총 함수**다. 각도 하나를 «빼면» 그것이 무엇이든 exit 4 여야 한다.
  # 열거를 도출해 돌므로 `ANGLES` 에 네 번째가 생기면 이 루프가 자동으로 그것도 잰다.
  local missing a f rc out
  while IFS= read -r missing; do
    [ -n "$missing" ] || continue
    f="$TMP/missing-$missing.txt"; : > "$f"
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      [ "$a" = "$missing" ] && continue
      printf '%s: filled\n' "$a" >> "$f"
    done <<< "$ANGLES"
    rc=0; out="$(python3 "$A" --angles "$f" 2>&1)" || rc=$?
    assert_eq "$rc" "4" "'$missing' 의 상태가 없으면 exit 4 (총 함수)"
    assert_contains "$out" "$missing" "오류가 빠진 각도의 이름을 댄다"
  done <<< "$ANGLES"
}

case_state_grammar_is_closed() {
  local f="$TMP/grammar.txt" rc st
  # 문법 «안» — 셋 다 선다
  for st in "filled" "absent" "folded_into:security-reviewer"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "0" "'$st' 는 문법 안이다"
  done
  # 문법 «밖» — 전부 exit 4. `folded_into:` 뒤가 비거나 공백이 섞인 것도 포함한다.
  # `folded_into:a/b` 는 한 토큰이라 줄 서식(`_LINE`)을 통과한다 — 수행자 이름
  # 검사(`_PERFORMER`)만 이것을 막는다. 이 값이 없으면 그 검사를 꺼도 GREEN 이었다.
  # 대문자·밑줄 수행자도 같은 검사만 막는다 — 수행자는 finding 의 `agent:`(소문자
  # kebab)와 정확 일치로 비교되므로(AC10a), `Security-Reviewer` 를 받으면
  # `security-reviewer` 가 낸 finding 과 다른 이름으로 조용히 통과한다.
  for st in "maybe" "folded_into:" "FILLED" "folded_into:two words" "folded_into:a/b" \
            "folded_into:Security-Reviewer" "folded_into:security_reviewer"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "'$st' 는 문법 밖이라 exit 4"
  done
}

case_absent_reason_grammar_is_closed() {
  # I1 (컨트롤러 ruling T2-a · 설계 §15) — `absent(<사유>)` 는 어느 각도에도 쓸 수
  # 있다. 사유는 `ANGLES`/`BLOCKING` 과 같은 방식으로 **모듈에게 물어** 가져온다.
  local f="$TMP/reason.txt" rc st
  # 문법 «안» — 두 사유 모두 선다
  while IFS= read -r st; do
    [ -n "$st" ] || continue
    write_angles "$f" "security: absent($st)" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "0" "'absent($st)' 는 문법 안이다"
  done <<< "$REASONS"
  # 문법 «밖» — 빈 괄호·모르는 사유·안 닫힌 괄호는 exit 4
  for st in "absent()" "absent(bogus)" "absent(not-installed"; do
    write_angles "$f" "security: $st" "adjudication: filled" "different-premise: filled"
    rc=0; python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "'$st' 는 문법 밖이라 exit 4"
  done
}

case_unknown_angle_is_fail_closed() {
  local f="$TMP/unknown.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: filled" \
                    "different-premise: filled" "made-up-angle: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 각도는 exit 4 — 각도 셋은 닫혀 있다"
}

case_duplicate_angle_is_fail_closed() {
  # 같은 각도가 두 줄이면 «어느 쪽이 참인지» 산출물만 보고는 복원할 수 없다.
  # 「마지막이 이긴다」로 두면 앞 줄을 조용히 덮는 경로가 열린다.
  local f="$TMP/dup.txt" rc=0
  write_angles "$f" "security: absent" "security: filled" \
                    "adjudication: filled" "different-premise: filled"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "같은 각도가 두 번 나오면 exit 4"
}

case_malformed_extra_line_is_fail_closed() {
  # I2 — 세 각도가 전부 유효해도 서식이 아닌 «여분» 줄이 섞이면 exit 4 여야 한다.
  # `security:absent`(콜론 뒤 공백 없음)는 `_LINE` 패턴 밖이라 `parse()` 의
  # 「서식이 아니다」 절이 이 줄에서 발동해야 한다. 그 절이 조용히 `continue` 로
  # 바뀌어도(누락 각도 검사만으로는 못 잡는다 — 세 각도가 이미 다 채워져 있어서)
  # 이 케이스가 없으면 스위트가 그대로 GREEN 이다. 컨트롤러 지시대로 이 케이스의
  # 이빨은 mutation 으로 직접 확인했다(리포트 "Fix round 1" 절 참고).
  local f="$TMP/malformed-extra.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: filled" \
                    "different-premise: filled" "security:absent"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "형식이 아닌 여분 줄이 섞이면 exit 4"
}

case_comment_and_blank_lines_are_skipped() {
  # `parse()` 의 건너뛰기 절(빈 줄 · `#` 주석)의 양의 짝. 음의 케이스만 있으면 이
  # 절을 지워도(주석·빈 줄이 서식 오류로 exit 4 가 돼도) 스위트가 GREEN 이었다.
  # 주석은 상태 줄 «모양»으로 적는다 — 건너뛰지 않으면 서식 오류이거나 중복이다.
  local f="$TMP/comment.txt" out rc=0
  write_angles "$f" "# security: absent" "" "security: filled" "   " \
                    "adjudication: filled" "different-premise: filled"
  out="$(python3 "$A" --angles "$f" 2>&1)" || rc=$?
  assert_eq   "$rc"  "0"                   "주석 줄과 빈 줄은 건너뛴다 (exit 0)"
  assert_grep "$out" '^  security: filled$' "주석 속 상태는 읽히지 않는다"
}

case_absent_reasons_are_exactly_three() {
  # 리터럴 핀 — 모듈에서 도출하면 사유를 몰래 넓히는 변이와 함께 늘어난다(PR3 변이 23).
  # 셋째 `source-failed` 는 계획 R-L: 관측된 주 입력 사망을 선언 위에 얹는 값이다.
  assert_eq "$(printf '%s\n' "$REASONS" | sort | tr '\n' ' ')" \
            "not-derived not-installed source-failed " \
            "부재 사유는 not-installed · not-derived · source-failed 셋뿐이다"
}

case_blocking_angles_are_exactly_two() {
  # AC11 · AC12 의 비대칭 자체를 핀한다. 「다른 전제」가 `BLOCKING_ANGLES` 에
  # 들어가면 모델 다양성 손실이 게이트가 된다 — 헌장 위반이다. 반대로 보안·판정이
  # 빠지면 AC11 이 죽는다. 아래 두 행동 케이스는 «오늘의 값»만 재므로 집합 자체를
  # 핀하는 이 단언이 따로 필요하다.
  local got; got="$(printf '%s\n' "$BLOCKING" | sort | tr '\n' ' ')"
  assert_eq "$got" "adjudication security " \
    "막는 각도는 보안·판정 둘뿐이다 (다른 전제는 공시만 — AC12)"
}

case_absent_blocking_angle_sets_the_flag() {
  # AC11 의 «산출자» 쪽. 판정 «값» 은 합성기 경로(`case_synth_*`)가 잰다.
  local f="$TMP/absent.txt" out a b
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out="$(python3 "$A" --angles "$f")"
    assert_grep "$out" '^angle_absent: true$' "'$a' 가 absent 면 막는다"
  done <<< "$BLOCKING"
}

case_absent_non_blocking_angle_discloses_only() {
  # AC12 — 「다른 전제」의 부재는 **공시되되 막지 않는다**.
  local f="$TMP/dp-absent.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent"
  out="$(python3 "$A" --angles "$f")"
  assert_grep "$out"     '^  different-premise: absent$' "부재가 산출물에 **드러난다**"
  assert_grep "$out"     '^angle_absent: false$'         "그래도 막지 않는다"
  assert_not_grep "$out" '^angle_absent: true$'          "막는다고 말하지 않는다"
}

case_absent_reason_blocks_when_angle_is_blocking() {
  # I1 — 사유가 있어도 **막는 각도**(BLOCKING_ANGLES)면 여전히 막는다. 사유는
  # 「무엇 때문에 부재했는가」를 공시할 뿐 막는지 여부는 여전히 각도가 가른다.
  local f="$TMP/reason-block.txt" out a b
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    : > "$f"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      if [ "$b" = "$a" ]; then printf '%s: absent(not-derived)\n' "$b" >> "$f"
      else printf '%s: filled\n' "$b" >> "$f"; fi
    done <<< "$ANGLES"
    out="$(python3 "$A" --angles "$f")"
    assert_grep "$out" '^angle_absent: true$' "'$a' 가 absent(not-derived) 면 여전히 막는다"
  done <<< "$BLOCKING"
}

case_absent_reason_on_non_blocking_angle_discloses_only() {
  # I1 — AC12 짝. 「다른 전제」의 부재는 사유가 붙어도 공시만 하고 막지 않는다.
  local f="$TMP/dp-reason.txt" out
  write_angles "$f" "security: filled" "adjudication: filled" "different-premise: absent(not-installed)"
  out="$(python3 "$A" --angles "$f")"
  assert_grep "$out"     '^  different-premise: absent\(not-installed\)$' "부재 사유가 산출물에 그대로 드러난다"
  assert_grep "$out"     '^angle_absent: false$'                          "그래도 막지 않는다"
  assert_not_grep "$out" '^angle_absent: true$'                           "막는다고 말하지 않는다"
}

case_self_adjudication_is_rejected() {
  # AC10a — 판정 각도가 **그 실행에서 finding 을 낸** 수행자에게 접히면 exit 4.
  local f="$TMP/self.txt" rc=0 out
  write_angles "$f" "security: filled" "adjudication: folded_into:security-reviewer" \
                    "different-premise: filled"
  out="$(python3 "$A" --angles "$f" --author security-reviewer 2>&1)" || rc=$?
  assert_eq "$rc" "4" "자기 finding 자기 판정은 exit 4"
  assert_contains "$out" "security-reviewer" "오류가 그 수행자의 이름을 댄다"
  # 이름은 수행자 문법 오류 메시지에도 나온다 — 원인(AC10a)을 따로 핀한다.
  assert_contains "$out" "AC10a" "exit 4 의 원인이 AC10a 다 (수행자 문법 오류가 아니다)"
}

case_folding_into_a_silent_reviewer_is_ok() {
  # 같은 모양인데 그 수행자가 finding 을 «안 냈으면» 정상이다 — C13 이 허용한
  # 접어 넣기다. 이 케이스가 없으면 위 케이스는 「folded_into 를 전부 막는다」와
  # 구별되지 않는다(양의 짝).
  local f="$TMP/fold-ok.txt" rc=0
  write_angles "$f" "security: filled" "adjudication: folded_into:scout" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "finding 을 안 낸 리뷰어에게 접는 것은 정상이다"
}

case_security_angle_may_fold_into_its_own_author() {
  # AC10a 의 **범위 한정**. 보안 각도는 «무엇을 찾는가» 의 문제라 그 리뷰어가
  # finding 을 내는 것이 정상이다. 여기에 같은 금지를 걸면 C13 의 접어 넣기가
  # 사실상 죽는다 — 설계가 명시적으로 뺀 자리다.
  local f="$TMP/sec-fold.txt" rc=0
  write_angles "$f" "security: folded_into:security-reviewer" "adjudication: filled" \
                    "different-premise: filled"
  python3 "$A" --angles "$f" --author security-reviewer >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "보안 각도에는 AC10a 를 적용하지 않는다"
}

case_forbidden_set_is_adjudication_only() {
  # 위 두 케이스는 «오늘의 두 각도»만 잰다. 금지 집합 자체를 핀해야 세 번째
  # 각도가 조용히 편입되거나 판정 각도가 조용히 빠지는 것을 잡는다.
  local got; got="$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import angles
print(' '.join(sorted(angles.SELF_ADJUDICATION_FORBIDDEN)))")"
  assert_eq "$got" "adjudication" "AC10a 의 대상은 판정 각도 하나다"
}

case_missing_file_is_fail_closed() {
  local rc=0; python3 "$A" --angles "$TMP/nope.txt" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "각도 파일이 없으면 exit 4 (조용히 clean 으로 새지 않는다)"
}

case_empty_flag_is_usage_error() {
  # exit 2 와 exit 4 를 가른다 — 빈 인자는 «잘못된 호출»이지 «실패한 판정»이 아니다.
  local rc=0; python3 "$A" --angles "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "빈 경로는 usage 오류(exit 2)"
  rc=0; python3 "$A" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "경로를 아예 안 주면 usage 오류(exit 2)"
}

case_non_utf8_is_fail_closed() {
  # 형제 `verdict.read_or_none()` 이 네 번째 재발로 얻은 절이다 —
  # `UnicodeDecodeError` 는 `ValueError` 의 하위이지 `OSError` 가 아니라서,
  # `except OSError` 만 두면 raw traceback + exit 1 로 0/2/4 계약을 탈출한다.
  # 픽스처는 **유효한 본문 뒤에** 나쁜 바이트를 붙인다 — 파일 전체가 쓰레기면
  # 서식 오류로도 exit 4 가 나서 green-for-the-wrong-reason 이 된다.
  local f="$TMP/bad.bin" rc=0
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$f"
  printf '# \xff\xfe\n' >> "$f"
  python3 "$A" --angles "$f" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "비-UTF-8 각도 파일은 exit 4 (traceback 이 아니다)"
}

case_all_three_filled_is_ok
case_every_angle_is_required
case_state_grammar_is_closed
case_absent_reason_grammar_is_closed
case_unknown_angle_is_fail_closed
case_duplicate_angle_is_fail_closed
case_malformed_extra_line_is_fail_closed
case_comment_and_blank_lines_are_skipped
case_absent_reasons_are_exactly_three
case_blocking_angles_are_exactly_two
case_absent_blocking_angle_sets_the_flag
case_absent_non_blocking_angle_discloses_only
case_absent_reason_blocks_when_angle_is_blocking
case_absent_reason_on_non_blocking_angle_discloses_only
case_self_adjudication_is_rejected
case_folding_into_a_silent_reviewer_is_ok
case_security_angle_may_fold_into_its_own_author
case_forbidden_set_is_adjudication_only
case_missing_file_is_fail_closed
case_empty_flag_is_usage_error
case_non_utf8_is_fail_closed
case_synth_angles_off_equals_on_minus_block
case_synth_blocking_absent_is_not_certified
case_synth_different_premise_absent_stays_clean
case_synth_self_adjudication_is_atomic_failure
case_synth_folding_into_a_silent_reviewer_is_ok
case_synth_suppressed_finding_still_counts_as_authored
case_synth_rejected_finding_still_counts_as_authored
case_synth_reviewer_sources_do_not_displace_agent
case_synth_promoted_finding_counts_as_authored
case_synth_rejected_finding_of_another_reviewer_is_ok
case_synth_angles_flag_hygiene
case_synth_primary_source_death_is_angle_absent
case_synth_missing_adjudicator_doc_is_angle_absent
case_synth_unusable_adjudicator_doc_is_angle_absent
case_synth_dead_adjudicator_with_findings_is_not_findings_lost
case_synth_adjudicator_given_but_absent_differs_from_not_given
case_synth_effective_angles_show_the_dead_source
case_synth_dead_adjudicator_does_not_launder_self_adjudication
case_dead_sources_only_for_blocking_angles
case_orchestrator_may_declare_source_failed
case_synth_author_identity_is_grammar_checked
case_synth_finding_without_agent_is_rejected_under_angles
case_synth_well_formed_authors_pass_identity
case_reviewer_persona_agent_literal_is_its_name
finish
