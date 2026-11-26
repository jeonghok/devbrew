#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md
# test_detector_failure_e2e.sh — 탐지 리뷰어(보안 · 외부)의 끝 값 대조가 실패해도 그 응답의 지적이 재비판과
# 합성을 거쳐 고칠 목록에 오르고, 리뷰어는 실패로 세어진다(설계 §1 · AC27 · AC35 · AC2).
#
# 본문 SKILL.md 의 펜스를 표지로 뽑아 임시 리포의 가짜 세션에서 차례로 돌린다 — RV 만들기 → 칸 사본 →
# 응답 사본 · 대조 → 리뷰어 대조 → (응답을 지적 목록으로 옮기는 걸음만 시험이 모델 대신 한다) →
# Step 3.5 익명화 → Step 4 합성.
#
# 케이스:
#   security_failed_findings_kept — 끝 값 없는 보안 응답(두 시도) → 리뷰어 대조 `security: fail: 끝 값 없음` →
#                                   지적이 익명 목록과 합성 출력의 고칠 목록에 있고 판정은 not-certified(angle-absent).
#                                   대조가 응답 사본을 건드리지 않는다.
#   external_failed_findings_kept — 외부 리뷰어 실패는 판정을 막지 않고 그 지적이 고칠 목록에 있다.
#   split_one_bundle_failed       — 보안 나눠 돌림 b1 맞음 · b2 값 없음 → 리뷰어 전체 실패, 두 묶음의 지적이 모두
#                                   익명 목록에.
#   two_externals_not_mixing      — 같은 실행의 외부 리뷰어 둘(ext-code-reviewer 맞음 · ext-pr-test-analyzer 값 없음)의
#                                   대조가 서로 섞이지 않는다.
#   no_session_copies_of_responses — 본문에서 `resp-` 는 `$RV/` 뒤에만 있다 · 세션 폴더에 응답 사본이 생기지 않는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
QGP="$ROOT/plugins/quality-gates"
SKILL="$QGP/skills/quality-pipeline/SKILL.md"
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' "plugins/quality-gates/skills/quality-pipeline/SKILL.md"; exit 0; }
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
FENCE="$QGP/tests/lib/skill_fence.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
P_RV='<Step 3 의 RV 절대 경로>'
SID="detfail01"

# fresh <이름> — 새 임시 리포 · 세션 폴더 · RV. G · RDIR · RVD 를 정한다.
fresh() {
  G="$T/$1"; mkdir -p "$G"
  git -C "$G" init -q && git -C "$G" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  RDIR="$G/.claude/quality-gates/$SID"; mkdir -p "$RDIR"
  printf 'diff --git a/src/a.py b/src/a.py\n--- a/src/a.py\n+++ b/src/a.py\n@@ -1 +1 @@\n-x\n+y\ndiff --git a/src/b.py b/src/b.py\n--- a/src/b.py\n+++ b/src/b.py\n@@ -1 +1 @@\n-p\n+q\n' > "$RDIR/review-i1.diff"
  printf '# 설계\n\n입력을 매개변수로 넘긴다.\n' > "$RDIR/intent.md"
  printf 'src/a.py\nsrc/b.py\n' > "$RDIR/review-i1.names"
  local out
  out="$(run_fence 'RV="$(mktemp -d)"' rv --sub '<8 hex>' 0a1b2c3d \
    --sub '<P3 에서 찍은 intent: 줄 — 한 줄, 글자 그대로>' 'intent: spec docs/x.md — 설계')"
  RVD="$(printf '%s\n' "$out" | sed -n 's/^RV: //p' | tail -1)"
  [ -n "$RVD" ] && [ -d "$RVD" ] || { no "$1: RV 펜스가 RV 를 만들지 못했다"; printf '%s\n' "$out" | sed 's/^/      /'; RVD="$T/$1-no-rv"; mkdir -p "$RVD"; }
}
# run_fence <표지> <이름> [--sub 옛 새]... — 펜스를 뽑아 채워 그 리포에서 돌린다.
run_fence() {
  local m="$1" n="$2"; shift 2
  python3 "$FENCE" "$SKILL" "$m" --sub '<session-id>' "$SID" "$@" > "$T/$n.sh" || { echo "FENCE-EXTRACT-FAILED $m"; return 99; }
  ( cd "$G" && TMPDIR="$T" CLAUDE_PLUGIN_ROOT="$QGP" bash "$T/$n.sh" ) 2>&1
}
slot() {        # <리뷰어> <시도>
  run_fence 'qg_nonce.py" attach "$RD/review-i1.diff"' slot --sub "$P_RV" "$RVD" --sub '<리뷰어 이름>' "$1" --sub '<시도 번호>' "$2"
}
split_slot() {  # <리뷰어> <묶음> <시도> <경로 줄들>
  run_fence "<<'QG_BUNDLE_<8 hex>'" split --sub "$P_RV" "$RVD" --sub '<리뷰어 이름>' "$1" \
    --sub '<묶음 번호>' "$2" --sub '<시도 번호>' "$3" --sub '<8 hex>' 1a2b3c4d --sub '<이 묶음의 파일 경로 — 한 줄에 하나>' "$4"
}
resp() {        # <리뷰어> <묶음> <시도> <응답 글>
  run_fence '"$RV/resp-${R}-b${B}-t${T}.txt" <<' resp --sub "$P_RV" "$RVD" --sub '<리뷰어 이름>' "$1" \
    --sub '<묶음 번호>' "$2" --sub '<시도 번호>' "$3" --sub '<8 hex>' 2b3c4d5e --sub '<리뷰어 응답 — 글자 그대로>' "$4"
}
checkrev() {    # <리뷰어>
  run_fence 'qg_nonce.py" check-reviewer' crf --sub "$P_RV" "$RVD" --sub '<리뷰어 이름>' "$1"
}
# values <리뷰어> <묶음> <시도> — 그 호출의 칸 사본 끝 줄들(응답 맨 앞에 적는 줄).
values() { tail -q -n 1 "$RDIR/review-i1-slot-$1-b$2-t$3-"*.txt; }
# prepare_and_synth <recritic 블록> — Step 3.5 익명화 펜스 → 재비판 응답 → Step 4 합성 펜스.
prepare_and_synth() {
  PREP_OUT="$(run_fence 'synthesize_findings.py" prepare' prep --sub "$P_RV" "$RVD")"; PREP_RC=$?
  # 재비판자는 칸 사본 넷의 끝 값을 응답 맨 앞에 적는다(Step 3.5 — 합성기가 견준다).
  { tail -q -n 1 "$RDIR"/review-i1-slot-recritic-b1-t1-*.txt
    printf '재비판을 마쳤다.\n\n```qg-recritic\n%s\n```\n' "$1"; } > "$RVD/recritic.txt"
  SYNTH_OUT="$(run_fence '--pre-merge-out "$RD/findings-pre-merge.yaml"' synth --sub "$P_RV" "$RVD" --sub '<위 표의 판정 입력>' '')"
}
yaml_finding() {  # <agent> <file> <severity> <summary>
  printf -- '- agent: %s\n  file: %s\n  line: 1\n  severity: %s\n  summary: "%s"\n  proposed_fix: "%s 를 고친다"\n' "$1" "$2" "$3" "$4" "$4"
}

note "── security_failed_findings_kept"
fresh sec
slot security 1 >/dev/null
SUM_S="보안 응답이 낸 문자열 이음 SQL"
R1="$(yaml_finding security-reviewer src/a.py SUGGESTION "$SUM_S")"
out="$(resp security 1 1 "$R1")"
assert_eq "$(printf '%s\n' "$out" | tail -1)" "fail: 끝 값 없음" "시도 1 — 끝 값 없는 응답은 그 호출의 실패"
slot security 2 >/dev/null
out="$(resp security 1 2 "$R1")"
assert_eq "$(printf '%s\n' "$out" | tail -1)" "fail: 끝 값 없음" "시도 2(한 번 다시 부름)도 실패"
cp "$RVD/resp-security-b1-t1.txt" "$T/r1.keep"
out="$(checkrev security)"
assert_eq "$(printf '%s\n' "$out" | tail -1)" "security: fail: 끝 값 없음" "리뷰어 대조 — security: fail: 끝 값 없음"
cmp -s "$RVD/resp-security-b1-t1.txt" "$T/r1.keep" && ok "대조는 응답 사본을 건드리지 않는다" || no "대조가 응답 사본을 바꿨다"
# 모델 몫 — 응답 사본의 지적을 지적 목록으로 옮긴다(대조 결과와 무관하게) · 각도 파일.
printf '%s\n' "$R1" > "$RVD/findings.yaml"
printf 'security: absent(source-failed)\nadjudication: filled\ndifferent-premise: absent\n' > "$RVD/angles.txt"
prepare_and_synth 'verdicts:
  - f: f1
    verdict: confirm'
assert_eq "$PREP_RC" "0" "Step 3.5 익명화 펜스가 0 으로 끝난다"
assert_eq "$(ls "$RDIR" | grep -c '^review-i1-slot-recritic-b1-t1-')" "4" "재비판 칸 사본 넷이 세션 폴더에 있다"
assert_not_contains "$SYNTH_OUT" "입력 실패(주): code-recritic" "끝 값을 적은 재비판 응답은 죽은 것으로 세지 않는다"
assert_contains "$(cat "$RVD/recritic-findings.yaml" 2>/dev/null)" "$SUM_S" "실패한 보안 응답의 지적이 익명 목록에 있다"
assert_contains "$SYNTH_OUT" "$SUM_S 를 고친다" "그 지적이 합성 출력의 고칠 목록에 있다"
assert_contains "$SYNTH_OUT" "verdict: not-certified" "판정은 not-certified"
assert_contains "$SYNTH_OUT" "reason: angle-absent" "사유는 angle-absent(보안 각도 부재)"

note "── external_failed_findings_kept"
fresh ext
slot security 1 >/dev/null
out="$(resp security 1 1 "$(values security 1 1)
[]")"
assert_eq "$(printf '%s\n' "$out" | tail -1)" "ok" "보안은 끝 값이 맞는다"
slot ext-code-reviewer 1 >/dev/null
SUM_E="외부 리뷰어가 낸 빠진 널 검사"
RE="$(yaml_finding code-reviewer src/b.py IMPORTANT "$SUM_E")"
resp ext-code-reviewer 1 1 "$RE" >/dev/null
slot ext-code-reviewer 2 >/dev/null
resp ext-code-reviewer 1 2 "$RE" >/dev/null
assert_eq "$(checkrev security | tail -1)" "security: ok" "보안 리뷰어 대조 ok"
assert_eq "$(checkrev ext-code-reviewer | tail -1)" "ext-code-reviewer: fail: 끝 값 없음" "외부 리뷰어 대조 실패"
printf '%s\n' "$RE" > "$RVD/findings.yaml"
printf 'security: filled\nadjudication: filled\ndifferent-premise: absent\n' > "$RVD/angles.txt"
prepare_and_synth 'verdicts:
  - f: f1
    verdict: confirm'
assert_contains "$(cat "$RVD/recritic-findings.yaml" 2>/dev/null)" "$SUM_E" "실패한 외부 응답의 지적이 익명 목록에 있다"
assert_contains "$SYNTH_OUT" "$SUM_E 를 고친다" "그 지적이 고칠 목록에 있다"
assert_contains "$SYNTH_OUT" "verdict: defect" "외부 리뷰어 실패는 판정을 막지 않는다(막는 지적이 판정을 정한다)"
assert_not_contains "$SYNTH_OUT" "verdict: not-certified" "판정이 not-certified 가 아니다"

note "── split_one_bundle_failed"
fresh split
split_slot security 1 1 'src/a.py' >/dev/null
split_slot security 2 1 'src/b.py' >/dev/null
SUM_1="묶음 1 의 지적"; SUM_2="묶음 2 의 지적"
F1="$(yaml_finding security-reviewer src/a.py SUGGESTION "$SUM_1")"; F2="$(yaml_finding security-reviewer src/b.py SUGGESTION "$SUM_2")"
assert_eq "$(resp security 1 1 "$(values security 1 1)
$F1" | tail -1)" "ok" "묶음 1 은 끝 값이 맞는다"
assert_eq "$(resp security 2 1 "$F2" | tail -1)" "fail: 끝 값 없음" "묶음 2 시도 1 은 값 없음"
split_slot security 2 2 'src/b.py' >/dev/null
assert_eq "$(resp security 2 2 "$F2" | tail -1)" "fail: 끝 값 없음" "묶음 2 시도 2 도 값 없음"
out="$(checkrev security)"
assert_contains "$out" "b1: ok" "묶음 1 은 ok"
assert_contains "$out" "b2: fail: 끝 값 없음" "묶음 2 는 실패"
assert_eq "$(printf '%s\n' "$out" | tail -1)" "security: fail: 끝 값 없음" "한 묶음이라도 실패면 리뷰어 전체 실패"
printf '%s\n%s\n' "$F1" "$F2" > "$RVD/findings.yaml"
printf 'security: absent(source-failed)\nadjudication: filled\ndifferent-premise: absent\n' > "$RVD/angles.txt"
prepare_and_synth 'verdicts:
  - f: f1
    verdict: confirm
  - f: f2
    verdict: confirm'
assert_contains "$(cat "$RVD/recritic-findings.yaml" 2>/dev/null)" "$SUM_1" "맞은 묶음의 지적이 익명 목록에"
assert_contains "$(cat "$RVD/recritic-findings.yaml" 2>/dev/null)" "$SUM_2" "실패한 묶음의 지적도 익명 목록에"

note "── two_externals_not_mixing"
fresh two
slot ext-code-reviewer 1 >/dev/null
slot ext-pr-test-analyzer 1 >/dev/null
resp ext-code-reviewer 1 1 "$(values ext-code-reviewer 1 1)
지적 없음" >/dev/null
resp ext-pr-test-analyzer 1 1 "$(values ext-code-reviewer 1 1)
남의 끝 값을 적었다" >/dev/null
assert_eq "$(checkrev ext-code-reviewer | tail -1)" "ext-code-reviewer: ok" "외부 리뷰어 1 은 자기 칸 값으로 ok"
assert_eq "$(checkrev ext-pr-test-analyzer | tail -1)" "ext-pr-test-analyzer: fail: 끝 값 없음" "외부 리뷰어 2 는 다른 리뷰어의 값을 적어도 실패 — 섞이지 않는다"
assert_eq "$(ls "$RDIR" | grep -c 'review-i1-slot-ext-')" "4" "외부 리뷰어마다 칸 사본 둘(의도 · diff)"

note "── no_session_copies_of_responses"
assert_not_grep "$(cat "$SKILL")" '\$RD/resp-' "본문에 세션 폴더의 응답 사본(\$RD/resp-)이 없다"
bad_resp="$(grep -o '.\{0,4\}resp-' "$SKILL" | grep -v '\$RV/resp-' || true)"
[ -z "$bad_resp" ] && ok "본문의 resp- 는 모두 \$RV/ 뒤에 있다" || { no "\$RV/ 밖의 resp- 가 있다"; printf '%s\n' "$bad_resp" | sed 's/^/      /'; }
assert_count_ge "grep -c '\$RV/resp-' '$SKILL'" 1 "본문이 응답 사본을 \$RV 에 쓴다(양성 짝)"
left="$(find "$T" -path '*/.claude/quality-gates/*' -name 'resp-*' 2>/dev/null)"
[ -z "$left" ] && ok "돌린 세션 폴더 어디에도 응답 사본이 없다" || { no "세션 폴더에 응답 사본이 생겼다"; printf '%s\n' "$left" | sed 's/^/      /'; }

finish
