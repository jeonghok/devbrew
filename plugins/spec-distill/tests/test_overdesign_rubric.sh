#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# 설계자 시선 축(`overdesign`)이 두 문서 자리의 프로필 본문에 실제로 서 있는가.
# 축 «이름»만 layer1 에 넣으면 리뷰어는 그 축이 무엇을 묻는지 어디서도 못 읽는다 —
# 이름은 rubric 목록이, 내용은 본문 절이 진다.
#
# 이 락이 재는 것은 «문구의 실재»다. 리뷰어의 실제 판정이 그 절차를 따랐는지는 못 잰다
# (설계 §7 「상한의 무이빨」과 같은 종류의 한계 — 공시하고 닫지 않는다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'plugins/spec-distill/references/docreview-profiles/brief.md' \
                  'plugins/spec-distill/references/docreview-profiles/design-doc.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
B="plugins/spec-distill/references/docreview-profiles/brief.md"
D="plugins/spec-distill/references/docreview-profiles/design-doc.md"

# 본문만 본다 — frontmatter 가 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정을 막는다.
body_of() { awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$1"; }
BB="$(body_of "$B")"; DB="$(body_of "$D")"
[ -n "$BB" ] && [ -n "$DB" ] \
  && ok "양의 짝: 두 프로필 본문을 읽었다 (아래 전부가 공허하지 않다)" \
  || { no "프로필 본문 추출 실패 — 아래 전부가 공허하다"; finish; exit; }

has() {   # has <본문> <문구> <설명>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 문구 부재: $2" ;; esac
}
hasnt() { # hasnt <본문> <문구> <설명>
  case "$1" in *"$2"*) no "$3 — 있으면 안 되는 문구: $2" ;; *) ok "$3" ;; esac
}

# ── AC5 : layer1 에 축이 있고 한 줄이다 ───────────────────────────────────
for f in "$B" "$D"; do
  n="$(grep -c '^  layer1: .*overdesign' "$f" || true)"
  [ "${n:-0}" -eq 1 ] \
    && ok "AC5: $f 의 layer1 «한 줄»에 overdesign 이 있다" \
    || no "AC5: $f 의 layer1 한 줄에 overdesign 이 없다 (줄바꿈이면 codex 축이 죽고 lay_of 가 덜 잰다)"
done
grep -q '^  layer1: \[direction, overdesign\]$' "$B" \
  && ok "AC5: brief layer1 == [direction, overdesign]" \
  || no "AC5: brief layer1 이 [direction, overdesign] 이 아니다"
for a in goal_fit problem_definition scope architecture component_relations data_flow tradeoffs feasibility; do
  grep -q "^  layer1: .*\b$a\b" "$D" && ok "AC5: design layer1 에 기존 축 $a 가 남아 있다" \
                                     || no "AC5: design layer1 에서 기존 축 $a 가 사라졌다"
done

# ── AC6 : 두 불릿이 서로 다르고 각자 자기 술어를 담는다 ───────────────────
BL="$(printf '%s\n' "$BB" | grep '^- `overdesign`' | head -1)"
DL="$(printf '%s\n' "$DB" | grep '^- `overdesign`' | head -1)"
[ -n "$BL" ] && [ -n "$DL" ] && [ "$BL" != "$DL" ] \
  && ok "AC6: 두 자리의 overdesign 불릿이 실재하고 서로 다르다" \
  || no "AC6: overdesign 불릿이 없거나 두 자리가 같다 (brief='$BL' design='$DL')"
has "$BL" '사용자 원문'   "AC6: brief 불릿이 자기 상류(사용자 원문)를 기준어로 담는다"
has "$DL" '브리프 §1 Goal' "AC6: design 불릿이 자기 상류(브리프 §1 Goal)를 기준어로 담는다"
hasnt "$BL" '왜곡'        "AC6: brief 불릿에 술어 ②(왜곡)가 없다 (그 대상이 구조·구현이라 brief 에 없다)"
has "$DL" '왜곡'          "AC6: design 불릿에 술어 ②(왜곡)가 있다"

finish
