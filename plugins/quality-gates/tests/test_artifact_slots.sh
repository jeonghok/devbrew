#!/usr/bin/env bash
# 문서 비평 — 세션 폴더 · 병합된 지적 칸 사본 · 반박자 끝 값 대조(R7 §1 · AC1 · AC2 · AC4 · AC25 · AC33).
# 본문 펜스는 tests/lib/skill_fence.py 로 표지로 뽑아 임시 리포에서 돌린다 — 손으로 옮긴 사본이 아니다.
#   session_fence          세션 폴더 펜스: 시작 줄 없음 · 마커(result.md)가 선 폴더 · artifact-critique/ 몫 폴더
#   setup_refusal_stops    세션 id 꼴 밖이면 rc ≠ 0 · 멈춤 줄 · 몫 폴더 없음(옛 길로 돌아가지 않는다)
#   merged_written_under_session  2.5 펜스가 병합 원본과 끝 값 사본을 몫 폴더에 쓰고 작업 폴더에 merged.yaml 이 없다
#   round_commit_excludes_merged  라운드 커밋 · 변경 신호가 몫 폴더의 파일과 무관하다
#   dispatch_path_tag      반박자 dispatch 는 경로 칸만 싣는다
#   fences_end_to_end      2.5 → 응답 쓰기 → 4 합성 펜스: 끝 값을 적은 응답은 판정이 쓰이고, 빠진 응답은 degraded
#   synth_*                합성기 대조 — 값 없음 · 읽지 못함 · 인용 · 일부 · 블록 안의 값 줄 · 원본 그대로 · 사용법
set -u
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

S="$PLUGIN_ROOT/skills/artifact-critique/SKILL.md"
SYN="$PLUGIN_ROOT/scripts/synthesize_artifact_findings.py"
NONCE="$PLUGIN_ROOT/scripts/qg_nonce.py"
FENCE="$PLUGIN_ROOT/tests/lib/skill_fence.py"
STOP_LINE="[quality-gates] 문서 비평의 세션 폴더를 얻지 못했다 — 이 대상의 비평을 멈춘다"
SID=artslots0001

TMP="$(mktemp -d)"
[ -n "${TMP}" ] && [ -d "${TMP}" ] || { echo "mktemp -d 실패"; exit 1; }
trap 'rm -rf "${TMP}"' EXIT

mkrepo() {   # mkrepo <폴더> — 추적되는 doc.md 하나
  mkdir -p "$1" && git -C "$1" init -q -b main && git -C "$1" config user.name t \
    && git -C "$1" config user.email t@example.com && git -C "$1" config commit.gpgsign false || return 1
  printf '# 문서\n본문\n' > "$1/doc.md"
  git -C "$1" add doc.md && git -C "$1" commit -q -m init
}
fence() {   # fence <표지> <출력 파일> [--sub 옛 새]... — 본문 펜스를 뽑는다
  local marker="$1" out="$2"
  shift 2
  python3 "$FENCE" "$S" "$marker" "$@" > "$out"
}
run_fence() {   # run_fence <리포> <펜스 파일> — 세션 id 환경 변수 없이 리포에서 돈다
  ( cd "$1" && env -u CLAUDE_CODE_SESSION_ID CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PYTHONDONTWRITEBYTECODE=1 bash "$2" )
}
endval() { tail -n 1 "$1" | sed -n 's/^qg-slot-end: \([0-9a-f]\{16\}\)$/\1/p'; }
SETUP_MARK='setup-qg.sh" --ensure --session-id'
KEY_MARK='--phase key'
RESP_MARK='QG_ADV_RESP_'
SYNTH_MARK='--phase synth'
COMMON_SUBS=(--sub '<session-id>' "$SID" --sub '<대상 번호>' 1 --sub '<라운드 번호>' 1)

note "── session_fence"
R="$TMP/r1"; mkrepo "$R"
fence "$SETUP_MARK" "$TMP/setup.sh" --sub '<session-id>' "$SID"; assert_eq "$?" 0 "세션 폴더 펜스가 본문에 하나"
out="$(run_fence "$R" "$TMP/setup.sh" 2>"$TMP/setup.err")"; rc=$?
assert_eq "$rc" 0 "세션 폴더 펜스 rc 0"
assert_not_contains "$out$(cat "$TMP/setup.err")" "Quality Gates 를 시작한다" "no_start_line: qg 시작 줄을 내지 않는다"
AC="$R/.claude/quality-gates/$SID/artifact-critique"
[ -d "$AC" ]; assert_eq "$?" 0 "몫 폴더 artifact-critique/ 가 세션 폴더 아래에 있다"
[ -f "$R/.claude/quality-gates/$SID/result.md" ]; assert_eq "$?" 0 "세션 폴더에 마커 result.md 가 선다"
printf 'keep\n' > "$AC/keep.txt"
run_fence "$R" "$TMP/setup.sh" >/dev/null 2>&1
[ -f "$AC/keep.txt" ]; assert_eq "$?" 0 "두 번째 대상의 펜스는 몫 폴더를 지우지 않는다(--ensure)"

note "── setup_refusal_stops"
R="$TMP/r2"; mkrepo "$R"
fence "$SETUP_MARK" "$TMP/setup-bad.sh" --sub '<session-id>' 'bad id!'
run_fence "$R" "$TMP/setup-bad.sh" >"$TMP/bad.out" 2>"$TMP/bad.err"; rc=$?
[ "$rc" -ne 0 ]; assert_eq "$?" 0 "세션 id 꼴 밖이면 rc ≠ 0 (rc=${rc})"
assert_contains "$(cat "$TMP/bad.err")" "$STOP_LINE" "멈춤 줄"
assert_contains "$(cat "$TMP/bad.err")" "허용 모양" "setup-qg.sh 의 사유를 그대로 보인다"
[ ! -e "$R/.claude" ]; assert_eq "$?" 0 "몫 폴더 · 세션 폴더를 만들지 않는다"
fence "$SETUP_MARK" "$TMP/setup-env.sh" --sub '<session-id>' "$SID"
( cd "$R" && CLAUDE_CODE_SESSION_ID=othersess0002 CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$TMP/setup-env.sh" ) >/dev/null 2>"$TMP/env.err"; rc=$?
[ "$rc" -ne 0 ] && grep -q -F "$STOP_LINE" "$TMP/env.err"; assert_eq "$?" 0 "다른 세션 id 를 거절하면 멈춘다"
[ ! -e "$R/.claude/quality-gates/$SID/artifact-critique" ]; assert_eq "$?" 0 "거절된 세션에 몫 폴더가 없다"

note "── merged_written_under_session"
R="$TMP/r3"; mkrepo "$R"
run_fence "$R" "$TMP/setup.sh" >/dev/null 2>&1
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", proposed_fix: "fix A"}\n' > "$R/critic-1.yaml"
fence "$KEY_MARK" "$TMP/key.sh" "${COMMON_SUBS[@]}" \
  --sub '<--findings critic-1.yaml … --findings critic-k.yaml [--findings codex.yaml]>' '--findings critic-1.yaml'
assert_eq "$?" 0 "2.5 펜스가 본문에 하나이고 자리표가 있다"
run_fence "$R" "$TMP/key.sh" >"$TMP/key.out" 2>"$TMP/key.err"; assert_eq "$?" 0 "2.5 펜스 rc 0"
AC="$R/.claude/quality-gates/$SID/artifact-critique"
M="$AC/merged-t1-r1.yaml"; MS="$AC/merged-t1-r1-slot.txt"
grep -q 'dedup_key' "$M" 2>/dev/null; assert_eq "$?" 0 "병합 원본 merged-t1-r1.yaml 이 몫 폴더에 있다"
[ -n "$(endval "$MS")" ]; assert_eq "$?" 0 "끝 값 사본 merged-t1-r1-slot.txt 의 끝 줄"
[ "$(sed '$d' "$MS")" = "$(cat "$M")" ]; assert_eq "$?" 0 "사본 = 원본 + 끝 줄"
assert_eq "$(grep -c 'qg-slot-end' "$M")" 0 "원본에는 끝 줄이 붙지 않는다(AC25)"
assert_eq "$(find "$R" -name 'merged*.yaml' ! -path '*/.claude/*' | wc -l | tr -d ' ')" 0 "작업 폴더에 merged*.yaml 이 없다(AC2)"

note "── round_commit_excludes_merged"
sig_before="$(cd "$R" && bash "$PLUGIN_ROOT/scripts/artifact_change_signal.sh" doc.md)"
printf '# 문서\n고친 본문\n' > "$R/doc.md"
sig="$(cd "$R" && bash "$PLUGIN_ROOT/scripts/artifact_change_signal.sh" doc.md)"
assert_contains "$sig" "changed: true" "변경 신호는 대상 파일의 변경을 본다"
printf 'x\n' >> "$MS"
assert_eq "$(cd "$R" && bash "$PLUGIN_ROOT/scripts/artifact_change_signal.sh" doc.md)" "$sig" "몫 폴더의 파일이 바뀌어도 변경 신호는 같다"
assert_contains "$sig_before" "changed: false" "고치기 전 변경 신호(양의 짝)"
( cd "$R" && env -u DEVBREW_QUALITY_GATES_DISABLE -u DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE bash "$PLUGIN_ROOT/scripts/artifact_commit.sh" doc.md "critique(round 1): t" ) >/dev/null 2>&1
assert_eq "$(git -C "$R" show --name-only --format= HEAD)" "doc.md" "라운드 커밋 파일은 대상 하나 — 몫 폴더의 파일이 없다"

note "── dispatch_path_tag"
SF="$(cat "$S")"
assert_contains "$SF" '<merged_findings_file>${MERGED_FINDINGS_FILE}</merged_findings_file>' "반박자 dispatch 는 경로 칸"
assert_not_contains "$SF" '<merged_findings>${MERGED_FINDINGS}' "반박자 dispatch 에 글 칸이 없다"
assert_not_contains "$SF" '그대로 inline' "병합 내용을 프롬프트에 inline 하던 글이 없다"
assert_not_contains "$SF" 'merged.yaml' "작업 폴더의 merged.yaml 이 본문에 없다"
assert_contains "$SF" 'QG_INPUT_UNREADABLE: <읽지 못한 경로>' "읽지 못함 한 줄 글자"
assert_contains "$SF" '--adversarial-response "$AC/adversarial-t${T}-r${R}.txt" --slot "$AC/merged-t${T}-r${R}-slot.txt"' "4 합성 펜스가 응답 전체와 칸 사본으로 대조한다"
assert_contains "$SF" '--phase synth --findings "$AC/merged-t${T}-r${R}.yaml"' "4 합성 펜스는 병합 원본을 읽는다"
assert_contains "$SF" '이번 라운드 adversarial 판정 실패(사유: `<degraded_reason>`<사유 괄호>) — 재시도 / 중단?' "판정 실패 질문에 사유 괄호 자리"
assert_contains "$SF" '`verdicts.yaml` 에는 응답 안의 YAML 블록만 쓴다' "verdicts.yaml 은 블록만(판정 C-4)"

note "── fences_end_to_end"
fence "$RESP_MARK" "$TMP/resp-tpl.sh" "${COMMON_SUBS[@]}" --sub '<8 hex>' 0a1b2c3d >/dev/null
assert_eq "$?" 0 "응답 쓰기 펜스가 본문에 하나"
fence "$SYNTH_MARK" "$TMP/synth.sh" "${COMMON_SUBS[@]}"; assert_eq "$?" 0 "4 합성 펜스가 본문에 하나"
K="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"][0]["dedup_key"])' "$M")"
v="$(endval "$AC/merged-t1-r1-slot.txt")"
# 위 round 시험이 사본 끝에 줄을 더했다 — 2.5 를 다시 돌려 새 사본을 만든다(재시도와 같은 길)
run_fence "$R" "$TMP/key.sh" >/dev/null 2>&1
v="$(endval "$MS")"
BLOCK="verdicts:
  - {finding_key: \"$K\", verdict: reject, evidence: \"근거 있음\"}"
resp_fence() {   # resp_fence <응답 전체> <블록 본문> — 응답 쓰기 펜스를 그 글로 채워 돈다
  python3 "$FENCE" "$S" "$RESP_MARK" "${COMMON_SUBS[@]}" --sub '<8 hex>' 0a1b2c3d \
    --sub '<반박자 응답 전체 — 글자 그대로. 응답이 없으면 빈 줄>' "$1" \
    --sub '<응답 안의 YAML 블록 본문만 — 블록 밖 글(qg-slot-end: 줄 포함)과 펜스 줄은 넣지 않는다. 블록이 없으면 빈 줄>' "$2" > "$TMP/resp.sh" \
    && run_fence "$R" "$TMP/resp.sh"
}
resp_fence "qg-slot-end: $v
\`\`\`yaml
$BLOCK
\`\`\`" "$BLOCK"; assert_eq "$?" 0 "응답 쓰기 펜스 rc 0"
[ -f "$AC/adversarial-t1-r1.txt" ] && grep -q "qg-slot-end: $v" "$AC/adversarial-t1-r1.txt"; assert_eq "$?" 0 "응답 전체가 adversarial-t1-r1.txt 에"
assert_eq "$(grep -c 'qg-slot-end' "$R/verdicts.yaml")" 0 "verdicts.yaml 에는 블록만(값 줄 없음)"
out="$(run_fence "$R" "$TMP/synth.sh" 2>/dev/null)"
assert_contains "$out" "degraded: false" "끝 값을 적은 응답 — 판정이 쓰인다"
assert_contains "$out" "adversarial_slot: ok" "대조 ok"
assert_contains "$out" "kept_critical: 0" "reject 가 반영됐다(양의 짝)"
resp_fence "$(printf '```yaml\n%s\n```' "$BLOCK")" "$BLOCK" >/dev/null 2>&1
out="$(run_fence "$R" "$TMP/synth.sh" 2>/dev/null)"
assert_contains "$out" "degraded_reason: adversarial" "값이 빠진 응답 — 판정 실패 길"
assert_contains "$out" "adversarial_slot: 끝 값 없음" "사유 끝 값 없음"
assert_contains "$out" "unadjudicated: 1" "값이 빠진 응답의 reject 는 쓰이지 않는다"

note "── synth (합성기 대조)"
D="$TMP/syn"; mkdir -p "$D"
printf 'findings:\n  - {agent: artifact-critic, category: logic, target_anchor: "#a", severity: CRITICAL, summary: "gap A", proposed_fix: "fix"}\n  - {agent: artifact-critic, category: logic, target_anchor: "#b", severity: IMPORTANT, summary: "gap B", proposed_fix: "fix"}\n' > "$D/critic.yaml"
python3 "$SYN" --phase key --findings "$D/critic.yaml" > "$D/merged.yaml" 2>/dev/null
cp "$D/merged.yaml" "$D/merged.orig"
python3 "$NONCE" attach "$D/merged.yaml" "$D/slot1.txt" >/dev/null
printf 'other slot\n' > "$D/other.src"; python3 "$NONCE" attach "$D/other.src" "$D/slot2.txt" >/dev/null
V1="$(endval "$D/slot1.txt")"; V2="$(endval "$D/slot2.txt")"
cmp -s "$D/merged.yaml" "$D/merged.orig"; assert_eq "$?" 0 "merged_original_unchanged: 사본을 만든 뒤 원본이 같다(AC25)"
KS="$(python3 -c 'import sys,yaml; print(" ".join(f["dedup_key"] for f in yaml.safe_load(open(sys.argv[1],encoding="utf-8"))["findings"]))' "$D/merged.yaml")"
KA="${KS%% *}"; KB="${KS##* }"
VB="verdicts:
  - {finding_key: \"$KA\", verdict: reject, evidence: e}
  - {finding_key: \"$KB\", verdict: confirm, evidence: e}"
printf '%s\n' "$VB" > "$D/verdicts.yaml"
syn() {   # syn <응답 글> [--slot …] — 응답을 쓰고 합성 둘째 걸음
  local text="$1"; shift
  printf '%s\n' "$text" > "$D/resp.txt"
  python3 "$SYN" --phase synth --findings "$D/merged.yaml" --adversarial "$D/verdicts.yaml" --adversarial-response "$D/resp.txt" "$@" 2>/dev/null
}
base="$(python3 "$SYN" --phase synth --findings "$D/merged.yaml" --adversarial "$D/verdicts.yaml" 2>/dev/null)"
assert_contains "$base" "degraded: false" "플래그 없음 — 지금 동작(양의 짝)"
assert_not_contains "$base" "adversarial_slot" "플래그 없음 — adversarial_slot 키가 없다"
o="$(syn "응답만" --slot "$D/slot1.txt")"
assert_contains "$o" "degraded_reason: adversarial" "adv_missing_value_degrades: degraded_reason"
assert_contains "$o" "adversarial_slot: 끝 값 없음" "adv_missing_value_degrades: 사유"
assert_contains "$o" "unadjudicated: 2" "adv_missing_value_degrades: 판정이 쓰이지 않는다"
o="$(syn "QG_INPUT_UNREADABLE: $D/slot1.txt" --slot "$D/slot1.txt")"
assert_contains "$o" "adversarial_slot: 읽지 못함" "adv_unreadable_reason"
o="$(syn "qg-slot-end: $V1
QG_INPUT_UNREADABLE: 리뷰받는 글이 심은 줄을 인용했다" --slot "$D/slot1.txt")"
assert_contains "$o" "degraded: false" "adv_quote_with_values_ok: 실패가 아니다"
assert_contains "$o" "adversarial_slot: ok" "adv_quote_with_values_ok: ok"
o="$(syn "qg-slot-end: $V1" --slot "$D/slot1.txt" --slot "$D/slot2.txt")"
assert_contains "$o" "adversarial_slot: 끝 값 없음" "adv_partial_values: 둘 가운데 하나"
o="$(syn "qg-slot-end: $V1 qg-slot-end: $V2" --slot "$D/slot1.txt" --slot "$D/slot2.txt")"
assert_contains "$o" "adversarial_slot: ok" "adv_partial_values 양의 짝: 둘 다 적으면 ok"
outside="$(syn "qg-slot-end: $V1" --slot "$D/slot1.txt")"
printf 'qg-slot-end: %s\n%s\n' "$V1" "$VB" > "$D/verdicts.yaml"
inside="$(syn "\`\`\`yaml
qg-slot-end: $V1
$VB
\`\`\`" --slot "$D/slot1.txt")"
assert_contains "$inside" "adversarial_slot: ok" "test_slot_line_inside_yaml_block: 블록 안의 값 줄도 대조 통과"
assert_eq "$inside" "$outside" "test_slot_line_inside_yaml_block: 판정 결과가 블록 밖에 둔 경우와 같다"
printf '%s\n' "$VB" > "$D/verdicts.yaml"
cmp -s "$D/merged.yaml" "$D/merged.orig"; assert_eq "$?" 0 "합성 뒤에도 병합 원본이 같다"
python3 "$SYN" --phase synth --findings "$D/merged.yaml" --adversarial "$D/verdicts.yaml" --slot "$D/slot1.txt" >/dev/null 2>&1
assert_eq "$?" 2 "--adversarial-response 없는 --slot 은 사용법 오류"
python3 "$SYN" --phase synth --findings "$D/merged.yaml" --adversarial "$D/verdicts.yaml" --adversarial-response "$D/resp.txt" --slot "" >/dev/null 2>&1
assert_eq "$?" 2 "빈 --slot 은 사용법 오류"
o="$(python3 "$SYN" --phase synth --findings "$D/merged.yaml" --adversarial "$D/verdicts.yaml" --adversarial-response "$D/none.txt" --slot "$D/slot1.txt" 2>/dev/null)"
assert_contains "$o" "adversarial_slot: 끝 값 없음" "응답 파일이 없으면 끝 값 없음(fail-closed)"

note "── QG_NAMES"
assert_eq "$(grep -c -F -- "artifact-critique/(merged-t[0-9]+-r[0-9]+(\\.yaml|-slot\\.txt)|adversarial-t[0-9]+-r[0-9]+\\.txt)" "$PLUGIN_ROOT/scripts/review-diff.sh")" 1 "QG_NAMES: artifact-critique 몫 폴더 꼴"
assert_contains "$(cat "$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md")" '`artifact-critique/`' "상태 문서: 몫 폴더"

finish
