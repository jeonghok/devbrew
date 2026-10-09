#!/usr/bin/env bash
# test_skill_run_contract.sh — 파이프라인 SKILL 의 실행 단위 계약 (K-1 · K-2 · K-3 · AC7).
#
# P2 — 매 실행은 새 세션 폴더에서 시작한다: 끝난 앞 실행(`## 판정` 이 있는 result.md)이면 setup 을
#      --ensure 없이 다시 불러 폴더를 다시 만들고, 실행 단위 파일을 지운다. P2 펜스를 SKILL 에서
#      뽑아 임시 리포에서 실제로 돌린다.
# F  — Final verdict 펜스가 판정 줄 숫자를 셸이 뽑은 값으로 넘긴다(자리표시 금지).
# E  — 외부 리뷰어 프롬프트가 기준 블록과 의도 출처를 싣고, 그 dispatch 자리가 처분을 밝힌다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
QGP="$ROOT/plugins/quality-gates"
SKILL="$QGP/skills/quality-pipeline/SKILL.md"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

# ── P2 창: `**P2 — setup.**` 부터 `**P3` 앞까지
P2="$(awk '/^\*\*P2 — setup\.\*\*/{f=1} /^\*\*P3 /{f=0} f' "$SKILL")"
[ -n "$P2" ] && ok "P2 창을 찾았다" || { no "P2 창이 없다 — 아래가 공허하다"; finish; exit; }
FENCE="$(printf '%s\n' "$P2" | awk '/^```bash$/{f=1;next} f&&/^```$/{exit} f')"
[ -n "$FENCE" ] && ok "P2 펜스를 뽑았다" || { no "P2 펜스가 없다"; finish; exit; }

assert_grep "$FENCE" '^"\$QG/scripts/setup-qg\.sh" --ensure \$ARGUMENTS' "P2 는 setup 을 --ensure 로 부른다 (D-6)"
assert_grep "$FENCE" "grep -q '\^## 판정\\$' \"\\\$RD/result\.md\".*then \"\\\$QG/scripts/setup-qg\.sh\" \\\$ARGUMENTS" \
  "끝난 앞 실행(## 판정)이면 setup 을 --ensure 없이 다시 부른다"
for f in excluded.md aggregate.yaml verdict.out intent.md topic-scope.txt; do
  assert_grep "$FENCE" "^rm -f .*\"\\\$RD/$f\"" "P2 가 실행 단위 파일 $f 를 지운다"
done

# 실행 단위 파일은 SKILL 이 \$RD 아래에 쓰는 것에서 도출한다 — 새 파일이 생기면 P2 도 지워야 한다.
written="$(grep -oE '"\$RD/[A-Za-z0-9_.-]+"' "$SKILL" | sort -u | grep -v '"\$RD/result.md"')"
for w in $written; do
  printf '%s\n' "$FENCE" | grep -E '^rm -f ' | grep -qF "$w" \
    && ok "SKILL 이 쓰는 $w 를 P2 가 지운다" || no "SKILL 이 쓰는 $w 를 P2 가 지우지 않는다"
done
[ -n "$written" ] && ok "실행 단위 파일 도출이 비지 않았다" || no "실행 단위 파일 도출이 비었다"

# ── P2 행동: 임시 리포에서 펜스를 실제로 돌린다
SID="runcontract01"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
git -C "$T" init -q && git -C "$T" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
RUN="$T/p2.sh"
{ printf '%s\n' "$FENCE" | sed "s/<session-id>/$SID/g; s/\$ARGUMENTS//g"; } > "$RUN"
RDIR="$T/.claude/quality-gates/$SID"

seed_prev() {   # <with_verdict: 1|0>
  mkdir -p "$RDIR"
  printf -- '---\nsession_id: "%s"\nstarted_at: "2000-01-01T00:00:00Z"\n---\n\n# qg result\n' "$SID" > "$RDIR/result.md"
  [ "$1" = 1 ] && printf '\n## 판정\n\nqg: clean\n\n## 지적\n\n(없음)\n' >> "$RDIR/result.md"
  for f in excluded.md aggregate.yaml verdict.out intent.md topic-scope.txt; do echo old > "$RDIR/$f"; done
}

# (a) 끝난 앞 실행 — 폴더를 다시 만든다
seed_prev 1
( cd "$T" && CLAUDE_PLUGIN_ROOT="$QGP" CLAUDE_CODE_SESSION_ID="$SID" bash "$RUN" ) >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "(a) P2 펜스가 끝난 앞 실행 위에서 0 으로 끝난다"
assert_eq "$(grep -c '^## 판정$' "$RDIR/result.md" 2>/dev/null)" "0" "(a) 새 result.md 에 앞 실행의 ## 판정 이 없다"
grep -q '2000-01-01' "$RDIR/result.md" 2>/dev/null && no "(a) result.md 가 앞 실행의 것 그대로다" || ok "(a) result.md 가 새로 만들어졌다"
for f in excluded.md aggregate.yaml verdict.out intent.md topic-scope.txt; do
  [ -e "$RDIR/$f" ] && no "(a) 앞 실행의 $f 가 남았다" || ok "(a) 앞 실행의 $f 가 없다"
done

# (b) /qg 의 setup 이 막 만든 폴더(판정 없음) — result.md 는 그대로, 실행 단위 파일은 지운다
seed_prev 0
( cd "$T" && CLAUDE_PLUGIN_ROOT="$QGP" CLAUDE_CODE_SESSION_ID="$SID" bash "$RUN" ) >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "(b) P2 펜스가 새 폴더 위에서 0 으로 끝난다"
grep -q '2000-01-01' "$RDIR/result.md" 2>/dev/null && ok "(b) 판정 없는 result.md 는 --ensure 가 그대로 둔다" || no "(b) 판정 없는 result.md 가 다시 만들어졌다(setup 이중 실행)"
for f in excluded.md aggregate.yaml verdict.out intent.md topic-scope.txt; do
  [ -e "$RDIR/$f" ] && no "(b) $f 가 남았다" || ok "(b) $f 가 없다"
done

# (c) 하위 디렉토리에서 시작한 세션 (최종 리뷰 I2) — setup 과 RD 가 같은 최상위 폴더를 본다.
#     최상위 result.md 에 옛 ## 판정 이 있으면 하위에서 돈 P2 도 그 파일을 다시 만든다(K-2).
seed_prev 1
mkdir -p "$T/sub/deeper"
( cd "$T/sub/deeper" && CLAUDE_PLUGIN_ROOT="$QGP" CLAUDE_CODE_SESSION_ID="$SID" bash "$RUN" ) >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "(c) P2 펜스가 하위 디렉토리에서 0 으로 끝난다"
assert_eq "$(grep -c '^## 판정$' "$RDIR/result.md" 2>/dev/null)" "0" "(c) 하위에서 돈 P2 도 최상위 result.md 의 앞 실행 ## 판정 을 없앤다"
grep -q '2000-01-01' "$RDIR/result.md" 2>/dev/null && no "(c) 최상위 result.md 가 앞 실행의 것 그대로다" || ok "(c) 최상위 result.md 가 새로 만들어졌다"
[ ! -e "$T/sub/.claude" ] && [ ! -e "$T/sub/deeper/.claude" ] \
  && ok "(c) 하위 디렉토리에 세션 폴더를 만들지 않는다" || no "(c) 하위 디렉토리에 .claude 가 생겼다"

# (d) P3 펜스를 하위 디렉토리에서 — 의도 파일이 최상위 RD 에 써진다(I2 의 rc 3 재현 자리).
P3W="$(awk '/^\*\*P3 — intent source\.\*\*/{f=1} /^## Flow$/{f=0} f' "$SKILL")"
P3F="$(printf '%s\n' "$P3W" | awk '/^```bash$/{f=1;next} f&&/^```$/{exit} f')"
[ -n "$P3F" ] && ok "P3 펜스를 뽑았다" || no "P3 펜스가 없다"
assert_grep "$P3F" '^"\$QG/scripts/discover-spec\.sh" --intent-out "\$RD/intent\.md"$' "P3 는 의도 파일을 RD 에 쓴다"
assert_eq "$(printf '%s\n' "$P3F" | tail -n 1)" 'echo "intent rc=$?"' "M1: P3 펜스가 discover-spec 의 rc 를 바로 다음 줄에서 낸다"
assert_contains "$(printf '%s\n' "$P3W" | tr '\n' ' ')" 'print `intent: 없음 (discover-spec rc=<N>)` as that one line instead' \
  "M1: rc 가 0 이 아니면 intent: 줄이 그 rc 를 밝힌다"
RUN3="$T/p3.sh"
{ printf '%s\n' "$P3F" | sed "s/<session-id>/$SID/g"; } > "$RUN3"
out3="$( cd "$T/sub/deeper" && PATH=/usr/bin:/bin CLAUDE_PLUGIN_ROOT="$QGP" bash "$RUN3" 2>&1 )"
assert_contains "$out3" 'intent rc=0' "(d) 하위 디렉토리의 P3 가 rc 0 으로 끝난다 (최상위 RD 가 이미 있다)"
[ -f "$RDIR/intent.md" ] && ok "(d) 의도 파일이 최상위 RD 에 있다" || no "(d) 의도 파일이 최상위 RD 에 없다"

# (e) git 밖 — P2 는 멈추고 아무것도 쓰지 않는다(M4: RD 가 파일시스템 루트를 가리키지 않는다).
NG="$(mktemp -d)"
if git -C "$NG" rev-parse --show-toplevel >/dev/null 2>&1; then
  no "(e) mktemp 가 git 리포 안이다 — 잴 수 없다"
else
  ( cd "$NG" && CLAUDE_PLUGIN_ROOT="$QGP" CLAUDE_CODE_SESSION_ID="$SID" bash "$RUN" ) >/dev/null 2>"$T/e.err"; rc=$?
  assert_eq "$rc" "1" "(e) git 밖에서 P2 펜스는 exit 1 로 멈춘다"
  assert_contains "$(cat "$T/e.err")" "git 리포 밖이다" "(e) 멈춘 이유를 한 줄로 알린다"
  [ ! -e "$NG/.claude" ] && ok "(e) git 밖에서는 아무 폴더도 만들지 않는다" || no "(e) git 밖에서 .claude 를 만들었다"
fi
rm -rf "$NG"

# M4 — RD 를 쓰는 펜스는 전부 TOP 가드 바로 뒤에서 RD 를 정한다. rev-parse 실패를 삼키는 옛 꼴이 없다.
assert_eq "$(grep -cF 'RD="$(git rev-parse --show-toplevel)' "$SKILL")" "0" "M4: rev-parse 실패를 가드하지 않는 RD 대입이 없다"
nrd="$(grep -c '^RD="\${TOP}/\.claude/quality-gates/<session-id>"$' "$SKILL")"
[ "$nrd" -ge 5 ] && ok "M4: RD 는 TOP 에서 정한다 (${nrd}곳)" || no "M4: TOP 에서 RD 를 정하는 펜스가 모자라다 (${nrd}곳)"
unguarded="$(awk '/^RD="\$\{TOP\}\//{ if (prev !~ /^TOP="\$\(git rev-parse --show-toplevel\)" \|\| \{ echo .* >&2; exit 1; \}$/) print NR } {prev=$0}' "$SKILL")"
assert_eq "$unguarded" "" "M4: 모든 RD 대입 바로 앞 줄이 rev-parse 실패에 exit 1 하는 TOP 가드다"

# ── F: Final verdict 펜스의 판정 줄 숫자
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
[ -n "$FV" ] && ok "Final verdict 창을 찾았다" || no "Final verdict 창이 없다"
assert_eq "$(printf '%s\n' "$FV" | grep -cxF 'N_BLOCK=$(sed -n '"'"'s/^blocking: //p'"'"' "$SYN"); N_OPT=$(sed -n '"'"'s/^optional: //p'"'"' "$SYN")')" "1" \
  "F: 막는 지적 · 선택 수를 합성기 출력에서 셸이 뽑는다"
assert_eq "$(printf '%s\n' "$FV" | grep -cxF '  --blocking "$N_BLOCK" --optional "$N_OPT" --new-failures "$K" --excluded "$X" \')" "1" \
  "F: verdict.py 에 셸이 뽑은 네 수를 넘긴다"
assert_not_grep "$FV" '--(blocking|optional|new-failures|excluded)[ =]+"?<' "F: 판정 줄 숫자 자리에 자리표시(<N>)가 없다 (R24)"
assert_not_grep "$FV" ':-0\}' "F: 합성 출력의 결측을 0 으로 채우는 기본값이 없다 (V8 · 최종 리뷰 I3)"

# ── F 행동 (최종 리뷰 I3): 합성 출력이 없거나 · 비었거나 · 키가 빠졌거나 · 겹치면 판정 줄을 만들지 않는다.
#    Final verdict 의 첫 펜스를 임시 리포에서 실제로 돌린다.
FVF="$(printf '%s\n' "$FV" | awk '/^```bash$/{f=1;next} f&&/^```$/{exit} f')"
[ -n "$FVF" ] && ok "Final verdict 펜스를 뽑았다" || no "Final verdict 펜스가 없다"
RVD="$T/rv"; mkdir -p "$RVD" "$RDIR"
RUNF="$T/final.sh"
FVF_SRC="$FVF" python3 - "$RUNF" "$RVD" "$SID" <<'PY'
import sys
out, rv, sid = sys.argv[1], sys.argv[2], sys.argv[3]
import os
src = os.environ["FVF_SRC"]
src = src.replace("<마지막 iteration 의 RV>", rv).replace("<session-id>", sid).replace("<N>", "1")
open(out, "w", encoding="utf-8").write(src + "\n")
PY
[ -s "$RUNF" ] && ok "Final verdict 펜스 실행 파일을 만들었다" || no "Final verdict 펜스 실행 파일이 비었다"

final_case() {   # final_case <라벨> <synth.out 내용 | @missing> <기대 rc> <기대 stderr 조각 | ->
  rm -f "$RVD/synth.out" "$RDIR/verdict.out"
  [ "$2" = "@missing" ] || printf '%s' "$2" > "$RVD/synth.out"
  local out err rc
  out="$( cd "$T" && CLAUDE_PLUGIN_ROOT="$QGP" bash "$RUNF" 2>"$T/final.err" )"; rc=$?
  err="$(cat "$T/final.err")"
  assert_eq "$rc" "$3" "I3 $1: 펜스 rc"
  if [ "$3" = 4 ]; then
    assert_contains "$err" "$4" "I3 $1: 판정 줄을 만들지 않는 이유를 밝힌다"
    [ ! -e "$RDIR/verdict.out" ] && ok "I3 $1: verdict.out 을 쓰지 않는다" || no "I3 $1: verdict.out 이 생겼다"
    assert_not_contains "$out" 'qg: clean' "I3 $1: clean 판정 줄이 나오지 않는다"
  else
    assert_contains "$out" "$4" "I3 $1: 판정 줄"
  fi
}
GOOD=$'blocking: 1\noptional: 2\nverdict: defect\nreason: blocking\n'
final_case "정상(양성 짝)"   "$GOOD" 0 'qg: defect · 막는 지적 1 · 선택 2 · 차등 새 실패 0 · 제외 패치 0 · iter 1 · '
final_case "파일 없음"       "@missing" 4 '합성 출력이 없거나 비었다'
final_case "빈 파일"         ""         4 '합성 출력이 없거나 비었다'
final_case "verdict 빠짐"    $'blocking: 0\noptional: 0\n'                         4 "'verdict:' 줄이 정확히 한 번이 아니다"
final_case "blocking 빠짐"   $'optional: 0\nverdict: clean\n'                       4 "'blocking:' 줄이 정확히 한 번이 아니다"
final_case "optional 빠짐"   $'blocking: 0\nverdict: clean\n'                       4 "'optional:' 줄이 정확히 한 번이 아니다"
final_case "verdict 겹침"    $'blocking: 0\noptional: 0\nverdict: clean\nverdict: defect\n' 4 "'verdict:' 줄이 정확히 한 번이 아니다"
final_case "blocking 겹침"   $'blocking: 1\nblocking: 0\noptional: 0\nverdict: defect\n'   4 "'blocking:' 줄이 정확히 한 번이 아니다"

# ── E: 외부 리뷰어 프롬프트와 처분
EXT="$(awk '/^\*\*External reviewers\*\*/{f=1} f&&/^\*\*다른 전제 각도/{exit} f' "$SKILL")"
EXTF="$(printf '%s\n' "$EXT" | awk '/^```text$/{f=1;next} f&&/^```$/{exit} f')"
[ -n "$EXTF" ] && ok "외부 리뷰어 프롬프트 펜스를 찾았다" || no "외부 리뷰어 프롬프트 펜스가 없다"
assert_contains "$EXTF" '<criteria>${CRITERIA}</criteria>' "E: 외부 리뷰어 프롬프트가 기준 블록을 싣는다"
assert_contains "$EXTF" '<intent>${INTENT}</intent>' "E: 외부 리뷰어 프롬프트가 의도 출처를 싣는다"
assert_contains "$EXT" '**처분** — consumer=orchestrator · fail-open · disclosure=실패' "외부 리뷰어 dispatch 자리가 처분을 밝힌다"
assert_grep "$EXT" 'marked `실패` in the iteration line' "처분의 disclosure 리터럴이 본문의 공시 문장에 실재한다"
finish
