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
export PYTHONDONTWRITEBYTECODE=1
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

# ── AC5 파서 일치 : layer1 이 «정말» 한 줄인가 (grep -c 는 대리일 뿐이다) ─────
# grep -c '^  layer1: .*overdesign' == 1 은 "layer1 과 overdesign 이 같은 줄에 있다"만
# 잰다 — «그 줄이 층 전체다»는 못 잰다. 줄바꿈이 overdesign 뒤에서 일어나면 그 대리는
# 통과한 채로 통과한다. 위험 자체를 잰다: PyYAML(전체를 본다)과 줄 기반 읽기(러너의
# _parse_frontmatter 및 T13 의 lay_of 가 쓰는 것과 같은 방식 — 그 줄만 본다)가 같은
# 목록을 내는지 비교한다. 줄바꿈되면 PyYAML 은 축 전부를 보고 줄 기반은 접두만 봐서
# 갈라진다 — 그 갈라짐이 codex 러너를 rc 5 profile_parse_ambiguous 로 죽이고 lay_of 를
# 덜 재게 만드는 바로 그 메커니즘이다.
pyyaml_layer1() {  # pyyaml_layer1 <파일> — layer_rubric.layer1 전체(줄 수 무관)
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" <<'PY'
import sys, yaml
p = sys.argv[1]
fm = open(p, encoding="utf-8").read().split("---")[1]
lr = yaml.safe_load(fm)["layer_rubric"]
print(",".join(lr["layer1"]))
PY
}
lineparse_layer1() {  # lineparse_layer1 <파일> — lay_of/러너와 같은 방식: layer1: 줄 «하나»만
  sed -n 's/^[[:space:]]*layer1:[[:space:]]*//p' "$1" | head -1 \
    | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' | sed -e 's/^ *//' -e 's/ *$//' | paste -sd, -
}
for f in "$B" "$D"; do
  PY_L1="$(pyyaml_layer1 "$f")"
  LN_L1="$(lineparse_layer1 "$f")"
  [ "$PY_L1" = "$LN_L1" ] \
    && ok "AC5: $f 의 layer1 — PyYAML 과 줄 기반 읽기가 같은 목록을 낸다 ($LN_L1)" \
    || no "AC5: $f 의 layer1 — PyYAML($PY_L1) 과 줄 기반 읽기($LN_L1) 가 다르다 (layer1 이 줄바꿈됐다)"
done

# ── AC5 불릿 커버리지 : layer1 의 축 «전부»가 body 에 자기 불릿을 갖는다 (파생 ∀) ──
# 파일 머리말의 계약 — 「이름은 rubric 목록이, 내용은 본문 절이 진다」 — 을 overdesign
# 하나가 아니라 축 «전부»에 닫는다. 목록은 layer1 에서 파생한다(열거하지 않는다) — 열째
# 축이 나중에 추가돼도 이 락이 자동으로 그 축을 검사 대상에 넣는다. 여덟 축의 불릿 «문구»
# 는 byte-pin 하지 않는다 — 그것은 이 PR 한 번의 사실이지 영구 불변식이 아니다(정본은
# git diff). 이 락이 고정하는 것은 «불릿의 존재»와 «축마다 서로 다른 불릿»뿐이다.
axes_of() {  # axes_of <파일> — layer1 이 한 줄일 때 그 원소들(한 줄이 아니면 공백)
  sed -n 's/^  layer1: \[\(.*\)\]$/\1/p' "$1" | tr ',' '\n' | sed -e 's/^ *//' -e 's/ *$//'
}
B_AXES="$(axes_of "$B")"; D_AXES="$(axes_of "$D")"
B_N="$(printf '%s\n' "$B_AXES" | grep -c '.' || true)"
D_N="$(printf '%s\n' "$D_AXES" | grep -c '.' || true)"
[ "${B_N:-0}" -eq 2 ] \
  && ok "양의 짝: brief layer1 에서 축 2개를 파생했다 (아래 ∀ 가 공허하지 않다)" \
  || no "양의 짝: brief layer1 파생이 2개가 아니다(실제 ${B_N:-0}개) — 아래 ∀ 가 공허할 수 있다"
[ "${D_N:-0}" -eq 9 ] \
  && ok "양의 짝: design layer1 에서 축 9개를 파생했다 (아래 ∀ 가 공허하지 않다)" \
  || no "양의 짝: design layer1 파생이 9개가 아니다(실제 ${D_N:-0}개) — 아래 ∀ 가 공허할 수 있다"

check_axis_bullets() {  # check_axis_bullets <본문> <라벨> <axes 개행 목록>
  # 불릿 텍스트는 흔히 "- `...`" 로 «-» 로 시작한다 — grep 의 패턴 인자로 그대로 넘기면
  # 옵션으로 오독된다. 그래서 중복 비교는 grep 을 거치지 않고 배열 원소 비교로 한다.
  local body="$1" label="$2" axes="$3" a pat line dup=0 prev
  local -a lines=()
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    pat='^- `'"$a"'`'
    line="$(printf '%s\n' "$body" | grep -- "$pat" | head -1)"
    if [ -n "$line" ]; then
      ok "AC5: $label 의 축 \`$a\` 가 body 에 불릿을 갖는다"
      for prev in "${lines[@]:-}"; do
        [ -n "$prev" ] && [ "$prev" = "$line" ] && dup=1
      done
      lines+=("$line")
    else
      no "AC5: $label 의 축 \`$a\` 가 body 에 불릿이 없다"
    fi
  done <<EOF_AXES
$axes
EOF_AXES
  [ "$dup" -eq 0 ] \
    && ok "AC5: $label 의 layer1 불릿들이 축마다 서로 다르다 (겹치는 문구 없음)" \
    || no "AC5: $label 의 layer1 불릿 중 최소 두 축이 같은 문구를 공유한다"
}
check_axis_bullets "$BB" "brief" "$B_AXES"
check_axis_bullets "$DB" "design" "$D_AXES"

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
