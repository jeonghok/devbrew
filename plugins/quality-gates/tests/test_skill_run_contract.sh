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

# ── F: Final verdict 펜스의 판정 줄 숫자
FV="$(awk '/^## Final verdict$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
[ -n "$FV" ] && ok "Final verdict 창을 찾았다" || no "Final verdict 창이 없다"
assert_eq "$(printf '%s\n' "$FV" | grep -cxF 'N_BLOCK=$(sed -n '"'"'s/^blocking: //p'"'"' "$SYN"); N_OPT=$(sed -n '"'"'s/^optional: //p'"'"' "$SYN")')" "1" \
  "F: 막는 지적 · 선택 수를 합성기 출력에서 셸이 뽑는다"
assert_eq "$(printf '%s\n' "$FV" | grep -cxF '  --blocking "${N_BLOCK:-0}" --optional "${N_OPT:-0}" --new-failures "$K" --excluded "$X" \')" "1" \
  "F: verdict.py 에 셸이 뽑은 네 수를 넘긴다"
assert_not_grep "$FV" '--(blocking|optional|new-failures|excluded)[ =]+"?<' "F: 판정 줄 숫자 자리에 자리표시(<N>)가 없다 (R24)"

# ── E: 외부 리뷰어 프롬프트와 처분
EXT="$(awk '/^\*\*External reviewers\*\*/{f=1} f&&/^\*\*다른 전제 각도/{exit} f' "$SKILL")"
EXTF="$(printf '%s\n' "$EXT" | awk '/^```text$/{f=1;next} f&&/^```$/{exit} f')"
[ -n "$EXTF" ] && ok "외부 리뷰어 프롬프트 펜스를 찾았다" || no "외부 리뷰어 프롬프트 펜스가 없다"
assert_contains "$EXTF" '<criteria>${CRITERIA}</criteria>' "E: 외부 리뷰어 프롬프트가 기준 블록을 싣는다"
assert_contains "$EXTF" '<intent>${INTENT}</intent>' "E: 외부 리뷰어 프롬프트가 의도 출처를 싣는다"
assert_contains "$EXT" '**처분** — consumer=orchestrator · fail-open · disclosure=실패' "외부 리뷰어 dispatch 자리가 처분을 밝힌다"
assert_grep "$EXT" 'marked `실패` in the iteration line' "처분의 disclosure 리터럴이 본문의 공시 문장에 실재한다"
finish
